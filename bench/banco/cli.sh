#!/bin/bash
# Cliente Forge 1.8.9 (produccion, portablemc) en Xvfb :99 con el jar a probar.
# Uso: cli.sh start JAR [USUARIO] [CFGDIR] | stop | log
#  JAR    : jar del mod (obfuscado, el mismo que se instala). Va a mods/ junto con Schematica+LunatriusCore.
#  CFGDIR : carpeta con config a sembrar (se copia sobre /home/user/cli/config); vacio = conserva la actual.
#  EXTRA_MODS (env): jars extra (p.ej. LB++) separados por espacio.
B=/home/user/banco; C=/home/user/cli; export PATH=$PATH:$HOME/.local/bin
case "$1" in
  start)
    JAR=$2; U=${3:-TestBot}; CFG=$4
    pkill -f '[n]et.minecraft.launchwrapper' ; sleep 1
    pgrep Xvfb >/dev/null || { setsid nohup Xvfb :99 -screen 0 1280x720x24 +extension RANDR +extension GLX > /tmp/xvfb.log 2>&1 & sleep 2; }
    mkdir -p $C/mods $C/config; rm -f $C/mods/*.jar
    cp $B/mods-base/*.jar $C/mods/; cp "$JAR" $C/mods/; for m in $EXTRA_MODS; do cp "$m" $C/mods/; done
    [ -n "$CFG" ] && cp -r "$CFG"/. $C/config/
    cat > $C/options.txt <<O
renderDistance:8
fancyGraphics:false
ao:0
maxFps:30
enableVsync:false
pauseOnLostFocus:false
guiScale:2
lang:en_US
chatScale:0.7
O
    rm -f $C/logs/latest.log
    cd $C; DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 setsid nohup portablemc --main-dir /home/user/mc start --mc-dir $C --jvm /usr/local/bin/java \
      --jvm-arg=-Xmx2G --jvm-arg=-Dctb.banco=1 -u "$U" --resolution 1280x720 --join-server 127.0.0.1 forge::1.8.9-11.15.1.2318-1.8.9 > /tmp/client.log 2>&1 &
    echo launched ;;
  stop) pkill -f '[n]et.minecraft.launchwrapper'; sleep 2; pkill -9 -f '[n]et.minecraft.launchwrapper'; echo stopped ;;
  log) tail -${2:-30} $C/logs/latest.log ;;
esac
