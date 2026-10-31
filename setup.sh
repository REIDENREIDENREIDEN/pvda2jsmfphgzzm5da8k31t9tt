#!/bin/bash
# Arma en una Ubuntu limpia (runner ubuntu-latest o VM) el mismo layout que usaban los bancos:
#   /home/user/mc        Forge 1.8.9-11.15.1.2318 (portablemc, archivos oficiales de Mojang/Forge)
#   /home/user/cli       carpeta del cliente (la crea banco/cli.sh)
#   /home/user/banco     cli.sh, drv.sh, mods-base/ (Schematica + LunatriusCore)
#   /home/user/sp/cache/patched_1.8.8.jar   Paper 1.8.8 (paperclip oficial)
#   /home/user/srv/plugins/HieloAgua.jar    printer emulado para la fase de cane
#   /home/user/emu, /home/user/emu-flujo    bancos terreno y flujo (copias de bench/)
# /home/user es un enlace a BASE (por defecto ~/work-root) para que los scripts corran sin cambios.
# Idempotente: lo que ya esta en CACHE / BASE/mc no se baja de nuevo (actions/cache guarda esas dos carpetas).
# Entorno: BASE, CACHE, JAVA8_HOME (si no esta: JAVA_HOME_8_X64 del runner, o se baja Temurin 8), SKIP_APT=1.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BASE=${BASE:-$HOME/work-root}
CACHE=${CACHE:-$BASE/.cache}
U=/home/user
FORGE=1.8.9-11.15.1.2318-1.8.9
PMC_VERSION=5.0.6
PAPER_URL=https://fill-data.papermc.io/v1/objects/7ff6d2cec671ef0d95b3723b5c92890118fb882d73b7f8fa0a2cd31d97c55f86/paper-1.8.8-445.jar
PAPER_SHA=7ff6d2cec671ef0d95b3723b5c92890118fb882d73b7f8fa0a2cd31d97c55f86
SCHEM_URL=https://mediafilez.forgecdn.net/files/2279/147/Schematica-1.8.9-1.7.7.143-universal.jar
SCHEM_SHA=a3498046d69f42b9ee6867f370e66e30504689e217a406e6aa5a13ba3397c41a
LUNA_URL=https://mediafilez.forgecdn.net/files/2272/942/LunatriusCore-1.8.9-1.1.2.32-universal.jar
LUNA_SHA=65432a76ef94fb6e3c7b1cdfc994d14d770ae0e0d032cf76f4528aadfb7e3259
JDK_URL=https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jdk/hotspot/normal/eclipse
T0=$(date +%s)
log() { echo "[setup +$(( $(date +%s) - T0 ))s] $*"; }
fetch() { # fetch URL DEST [SHA256]
  local url=$1 dest=$2 sha=${3:-}
  if [ -s "$dest" ] && { [ -z "$sha" ] || echo "$sha  $dest" | sha256sum -c --quiet - 2>/dev/null; }; then return 0; fi
  for i in 1 2 3; do curl -fsSL --retry 3 -o "$dest.part" "$url" && break; sleep 5; done
  [ -n "$sha" ] && { echo "$sha  $dest.part" | sha256sum -c --quiet - || { echo "sha256 distinto: $url"; exit 1; }; }
  mv "$dest.part" "$dest"
}

# 1) /home/user -> BASE
mkdir -p "$BASE" "$CACHE"
BASE=$(readlink -f "$BASE")
if [ "$(readlink -f $U 2>/dev/null)" != "$BASE" ]; then
  if [ -e $U ] && [ ! -L $U ]; then echo "$U ya existe y no es un enlace: usar BASE=$U"; exit 1; fi
  sudo ln -sfn "$BASE" $U
fi
log "BASE=$BASE (/home/user -> $(readlink -f $U))"

# 2) paquetes del sistema (Xvfb + Mesa llvmpipe + xdotool + ImageMagick para capturas)
if [ "${SKIP_APT:-0}" != 1 ]; then
  sudo apt-get update -qq >/dev/null
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    xvfb xdotool x11-utils x11-xserver-utils mesa-utils libgl1 libgl1-mesa-dri libglx-mesa0 \
    libxrandr2 libxcursor1 libxxf86vm1 libxtst6 libxi6 libxrender1 libfreetype6 fontconfig \
    imagemagick python3 python3-venv curl ca-certificates procps >/dev/null
  log "apt ok"
fi

# 3) Java 8 en /usr/local/bin (cli.sh usa /usr/local/bin/java; srv.sh usa java/javac/jar del PATH)
J8=${JAVA8_HOME:-${JAVA_HOME_8_X64:-}}
if [ -z "$J8" ] || [ ! -x "$J8/bin/javac" ]; then
  if [ ! -x "$CACHE/jdk8/bin/javac" ]; then
    fetch "$JDK_URL" "$CACHE/jdk8.tar.gz"
    rm -rf "$CACHE/jdk8"; mkdir -p "$CACHE/jdk8"; tar xzf "$CACHE/jdk8.tar.gz" -C "$CACHE/jdk8" --strip-components=1; rm -f "$CACHE/jdk8.tar.gz"
  fi
  J8=$CACHE/jdk8
fi
for b in java javac jar; do sudo ln -sfn "$J8/bin/$b" /usr/local/bin/$b; done
hash -r
java -version 2>&1 | head -1 | grep -q '"1\.8' || { echo "java no es 8: $(java -version 2>&1 | head -1)"; exit 1; }
# OpenJDK 8 de apt carga una clase de accesibilidad que mata AWT sin pantalla (Temurin no la trae).
sudo sed -i 's/^assistive_technologies/#assistive_technologies/' /etc/java-8-openjdk/accessibility.properties 2>/dev/null || true
log "java: $(java -version 2>&1 | head -1) ($J8)"

# 4) portablemc (lanzador por linea de comandos; cuenta offline con -u, sin cuentas Microsoft)
if [ ! -x "$BASE/.venv/bin/portablemc" ] || ! "$BASE/.venv/bin/pip" show -q portablemc 2>/dev/null | grep -q "^Version: $PMC_VERSION"; then
  rm -rf "$BASE/.venv"; python3 -m venv "$BASE/.venv"
  "$BASE/.venv/bin/pip" install -q --disable-pip-version-check "portablemc==$PMC_VERSION"
fi
mkdir -p "$HOME/.local/bin"; ln -sfn "$BASE/.venv/bin/portablemc" "$HOME/.local/bin/portablemc"
export PATH=$PATH:$HOME/.local/bin
log "portablemc $PMC_VERSION"

# 5) Forge 1.8.9 + librerias + assets (Mojang/Forge oficiales) en /home/user/mc
ok=0
for i in 1 2 3; do
  if portablemc --main-dir $U/mc start --dry --jvm /usr/local/bin/java forge::$FORGE > "$CACHE/pmc-install.log" 2>&1; then ok=1; break; fi
  log "portablemc intento $i fallo"; tr '\r' '\n' < "$CACHE/pmc-install.log" | grep -v Downloading | tail -5; sleep 10
done
[ $ok = 1 ] || { echo "no se pudo instalar Forge"; tr '\r' '\n' < "$CACHE/pmc-install.log" | grep -v Downloading | tail -40; exit 1; }
ls $U/mc/versions | grep -qi forge || { echo "falta la version forge en $U/mc/versions"; exit 1; }
log "forge ok: $(ls $U/mc/versions | tr '\n' ' ')"

# 6) Paper 1.8.8 parcheado (paperclip baja el server vanilla de Mojang y aplica el parche)
if [ ! -s "$CACHE/patched_1.8.8.jar" ]; then
  fetch "$PAPER_URL" "$CACHE/paper-1.8.8-445.jar" "$PAPER_SHA"
  W=$CACHE/paperclip-work; rm -rf "$W"; mkdir -p "$W"
  (cd "$W" && timeout 600 java -Dpaperclip.patchonly=true -jar "$CACHE/paper-1.8.8-445.jar" nogui < /dev/null > "$CACHE/paperclip.log" 2>&1 || true)
  [ -s "$W/cache/patched_1.8.8.jar" ] || { echo "paperclip no genero el jar"; tail -30 "$CACHE/paperclip.log"; exit 1; }
  mv "$W/cache/patched_1.8.8.jar" "$CACHE/patched_1.8.8.jar"; rm -rf "$W"
fi
mkdir -p $U/sp/cache; cp -f "$CACHE/patched_1.8.8.jar" $U/sp/cache/patched_1.8.8.jar
PAPER=$U/sp/cache/patched_1.8.8.jar
log "paper ok ($(sha256sum $PAPER | cut -c1-12))"

# 7) banco del cliente: cli.sh, drv.sh y los mods base (Schematica + LunatriusCore, desde el CDN de CurseForge)
mkdir -p $U/banco/mods-base
cp -f "$HERE"/bench/banco/*.sh $U/banco/
fetch "$SCHEM_URL" "$CACHE/Schematica-1.8.9-1.7.7.143-universal.jar" "$SCHEM_SHA"
fetch "$LUNA_URL" "$CACHE/LunatriusCore-1.8.9-1.1.2.32-universal.jar" "$LUNA_SHA"
cp -f "$CACHE"/Schematica-*.jar "$CACHE"/LunatriusCore-*.jar $U/banco/mods-base/

# 8) HieloAgua (printer emulado) compilado contra Paper
H=$(mktemp -d); mkdir -p $H/out $U/srv/plugins
javac -nowarn -source 1.8 -target 1.8 -cp $PAPER -d $H/out "$HERE"/bench/hielo/src/hielo/HieloAgua.java
cp "$HERE/bench/hielo/plugin.yml" $H/out/; (cd $H/out && jar cf $U/srv/plugins/HieloAgua.jar .); rm -rf $H
log "HieloAgua ok"

# 9) bancos: emu (terreno) y emu-flujo; se compila FactionsEmu de los dos (el ultimo, flujo, queda instalado)
for b in emu emu-flujo; do
  mkdir -p $U/$b; rm -rf $U/$b/plugin $U/$b/esc; cp -rf "$HERE/bench/$b/." $U/$b/
done
bash $U/emu/srv.sh build > "$CACHE/build-emu.log" 2>&1 || { cat "$CACHE/build-emu.log"; exit 1; }
bash $U/emu-flujo/srv.sh build > "$CACHE/build-flujo.log" 2>&1 || { cat "$CACHE/build-flujo.log"; exit 1; }
log "FactionsEmu ok (terreno + flujo)"
for c in Xvfb xdotool import python3 java javac jar portablemc; do command -v $c >/dev/null || { echo "falta $c"; exit 1; }; done
log "SETUP_DONE"
