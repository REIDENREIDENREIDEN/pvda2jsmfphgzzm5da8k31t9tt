#!/bin/bash
# (VM) Servidor emulador de un servidor de factions: Paper 1.8.8 + plugin FactionsEmu, mundo normal (montanas,
# cuevas, arboles, agua/lava) con bedrock plana y bloques flotantes, supervivencia, offline, vuelo permitido.
# TERRENO: LEVEL_TYPE (DEFAULT|AMPLIFIED|CUSTOMIZED|LARGEBIOMES) y GEN (generator-settings JSON) por entorno.
# Uso: srv.sh build | start [SEMILLA] | stop | reset | con "comando" [espera] | status | log [n]
#   build : compila el plugin contra /home/user/sp/cache/patched_1.8.8.jar (kit del banco) y lo instala
#   reset : borra el mundo y los datos del plugin (la proxima corrida genera todo de nuevo)
E=/home/user/emu; S=/home/user/emu-srv; PAPER=/home/user/sp/cache/patched_1.8.8.jar
mkdir -p $S/plugins
cd $S || exit 1
props() {
echo eula=true > eula.txt
cat > server.properties <<P
online-mode=false
level-type=${LEVEL_TYPE:-DEFAULT}
generator-settings=${GEN:-}
level-seed=${1:-canebot-emu}
gamemode=0
force-gamemode=false
spawn-protection=0
allow-flight=true
view-distance=8
difficulty=0
spawn-monsters=false
spawn-animals=false
spawn-npcs=false
max-tick-time=-1
motd=factions-emu
allow-nether=false
enable-rcon=false
op-permission-level=4
P
}
case "$1" in
  build)
    cd $E/plugin && rm -rf out && mkdir -p out && javac -source 1.8 -target 1.8 -nowarn -cp $PAPER -d out src/emu/*.java \
      && cp res/plugin.yml res/config.yml out/ && (cd out && jar cf ../FactionsEmu.jar .) && cp FactionsEmu.jar $S/plugins/ \
      && ls -la $S/plugins/FactionsEmu.jar ;;
  start)
    pgrep -f '[e]mu-srv.*server.jar\|[p]aper-emu' >/dev/null && { echo ya-corriendo; exit 0; }
    [ -s server.properties ] || props "$2"; [ -n "$2" ] && props "$2"
    cp -n $PAPER $S/paper-emu.jar
    rm -f in; mkfifo in; setsid nohup sleep infinity > in 2>/dev/null &
    setsid nohup java -Xmx2G -Djline.terminal=jline.UnsupportedTerminal -jar paper-emu.jar nogui < in > server.log 2>&1 &
    for i in $(seq 1 300); do grep -q 'Done (' server.log 2>/dev/null && { echo started; exit 0; }; sleep 1; done
    echo NO-ARRANCA; tail -20 server.log; exit 1 ;;
  stop)
    pgrep -f '[p]aper-emu' >/dev/null || { echo stopped; exit 0; }
    timeout 3 bash -c 'echo stop > in'
    for i in $(seq 1 40); do pgrep -f '[p]aper-emu' >/dev/null || break; sleep 1; done
    pkill -9 -f '[p]aper-emu'; pkill -f 'sleep infinity'; echo stopped ;;
  reset) rm -rf world world_nether world_the_end plugins/FactionsEmu/data.yml; echo reset ;;
  con) n=$(wc -l < server.log); timeout 3 bash -c "echo \"\$1\" > in" _ "$2"; sleep ${3:-1}; tail -n +$((n+1)) server.log ;;
  status) pgrep -f '[p]aper-emu' >/dev/null && echo up || echo down ;;
  log) tail -${2:-30} server.log ;;
esac
