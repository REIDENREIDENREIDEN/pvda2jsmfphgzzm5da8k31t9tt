#!/bin/bash
# (VM) Banco TERRENO r1: una preparacion completa con el cliente Forge real (Xvfb) contra el emulador, en un
# terreno elegido por entorno, y medicion de lo que pasa despues (primeros pilares del cane).
# Uso: run.sh JAR TAG   con entorno:
#   SEED (semilla), LEVEL_TYPE (DEFAULT|AMPLIFIED|CUSTOMIZED|LARGEBIOMES), GEN (generator-settings JSON),
#   EMU_SED (sed sobre config.yml del emulador), N (busters, 55), RESUME_AT (s: corta y retoma), POST (s despues
#   del DONE para ver el cane, 120), MIN (minutos maximo, 25).
# Salida: /home/user/emu/out/TAG/ (logs) y una linea RES en /home/user/emu/out/results.txt
JAR=$(readlink -f "$1"); TAG=$2; N=${N:-55}; SEED=${SEED:-canebot-emu}; MIN=${MIN:-25}; POST=${POST:-120}
export LEVEL_TYPE GEN
E=/home/user/emu; B=/home/user/banco; O=$E/out/$TAG; C=/home/user/cli; S=/home/user/emu-srv
mkdir -p $O; rm -f $O/*
srv() { bash $E/srv.sh "$@"; }
bash $B/cli.sh stop >/dev/null 2>&1
srv stop >/dev/null; srv build >/dev/null || { echo "RES $TAG ERROR=build" >> $E/out/results.txt; exit 1; }
srv reset >/dev/null
rm -f $S/server.properties
mkdir -p $S/plugins/FactionsEmu; cp $E/plugin/res/config.yml $S/plugins/FactionsEmu/config.yml
[ -n "$EMU_SED" ] && sed -i "$EMU_SED" $S/plugins/FactionsEmu/config.yml
cp $S/plugins/FactionsEmu/config.yml $O/emu-config.yml
# Printer del servidor real para la fase de cane (hielo -> agua, sin limitador de C08): plugin HieloAgua del kit.
rm -f $S/plugins/HieloAgua.jar; [ "${HIELO:-1}" = 1 ] && cp /home/user/srv/plugins/HieloAgua.jar $S/plugins/ 2>/dev/null
srv start "$SEED" >/dev/null || { echo "RES $TAG ERROR=server" >> $E/out/results.txt; exit 1; }
cp $S/server.properties $O/
# Config del mod limpia en cada corrida (sin progreso de cane ni checkpoint de otra corrida).
rm -rf $C/config/canetowerbot $C/config/canetowerbot-* $C/logs/canebot-autosetup*.log
bash $B/cli.sh start "$JAR" TestBot >/dev/null
for i in $(seq 1 240); do grep -q 'TestBot joined the game\|TestBot\[.*logged in' $S/server.log && break; sleep 2; done
grep -q 'TestBot' $S/server.log || { echo "RES $TAG ERROR=cliente-no-entro" >> $E/out/results.txt; cp /tmp/client.log $O/; exit 1; }
# Spawn del mundo en el oceano (LARGEBIOMES): respiracion acuatica para que no se ahogue antes de /wild.
srv con "effect TestBot 13 1000000 1" 1 >/dev/null
sleep 25
srv con "cbgive TestBot $N" 2 >/dev/null
bash $B/drv.sh cmd "/cane config set autosetup.capture true"; sleep 1
T0=$(date +%s)
bash $B/drv.sh cmd "/cane preparar"
END=$((T0 + MIN * 60)); k=0; L=$C/logs/canebot-autosetup.log; cut=""
while [ $(date +%s) -lt $END ]; do
  sleep 5; k=$((k+1))
  [ $((k % 12)) = 0 ] && bash $B/drv.sh shot $O/t$((k*5)).png >/dev/null
  if [ -n "$RESUME_AT" ] && [ $(( $(date +%s) - T0 )) -ge $RESUME_AT ] && [ -z "$cut" ]; then
    cut=1; bash $B/drv.sh cmd "/cane preparar parar"; sleep 6; bash $B/drv.sh cmd "/cane preparar"; continue
  fi
  grep -aq ' DONE \| FAIL ' $L 2>/dev/null && break
  [ -z "$RESUME_AT" ] && grep -aq ' STOP ' $L 2>/dev/null && break
done
DUR=$(( $(date +%s) - T0 ))
DONE=0; grep -aq ' DONE ' $L 2>/dev/null && DONE=1
# El cane sigue POST segundos: primeros pilares.
if [ $DONE = 1 ]; then sleep $POST; bash $B/drv.sh shot $O/post.png >/dev/null; fi
srv con "emu check TestBot 3" 5 | grep -a 'EMU CHECK' | tail -1 > $O/check-final.txt
bash $B/drv.sh shot $O/fin.png >/dev/null
bash $B/drv.sh cmd "/cane stop"; sleep 2
cp $S/server.log $O/server.log; cp $C/logs/latest.log $O/cliente.log 2>/dev/null
cp $L $O/autosetup.log 2>/dev/null; cp $C/config/canetowerbot/autosetup.properties $O/ 2>/dev/null
grep -a '\[CHAT\]' $O/cliente.log | sed 's/.*\[CHAT\] //' > $O/chat.txt
SL=$O/server.log; AL=$O/autosetup.log
cnt() { grep -ac "$1" "$2" 2>/dev/null; }
CHK=$(grep -a 'EMU CHECK' $SL | head -1 | sed 's/.*EMU CHECK //')
FCHK=$(sed 's/.*EMU CHECK //' $O/check-final.txt)
RESULT=$(grep -a ' DONE \| FAIL ' $AL | tail -1 | cut -c14- | tr '\n' ' ')
TPREP=$(grep -a 'MSG Hueco' $AL | grep -o '[0-9]* s desde' | head -1 | cut -d' ' -f1)
VOFF=$(grep -a 'EMU VUELO off' $SL | awk '{for(i=1;i<=NF;i++) if($i=="en"){split($(i+1),a,","); if(a[2]+0>3) c++}} END{print c+0}')
BIOMAS=$(grep -a 'EMU WILD tp' $SL | grep -o 'bioma [A-Z_]*' | cut -d' ' -f2 | tr '\n' ',')
LINE="RES $TAG done=$DONE dur=$DUR tprep=${TPREP:-?} wild=$(cnt 'EMU WILD tp' $SL) busters=$(cnt 'EMU BUSTER puesto' $SL) repetidos=$(cnt 'EMU BUSTER repetido' $SL) dejo=$(cnt 'EMU BUSTER dejo' $SL) cooldown=$(cnt 'EMU BUSTER cooldown' $SL) territorio=$(cnt 'EMU BUSTER territorio' $SL) prohibidos=$(cnt 'EMU PROHIBIDO' $SL) create=$(cnt 'EMU CREATE' $SL) claim=$(cnt 'EMU CLAIM' $SL) trabado=$(cnt 'Choque/trabado' $AL) sincamino=$(cnt 'sin camino a' $AL) noapoyo=$(cnt 'No encuentro donde apoyar' $AL) rebust=$(cnt 'no termino de borrarse' $AL) clienteNo=$(cnt 'el cliente no coloco' $AL) sinconf=$(cnt 'sin confirmacion del buster' $AL) caidas=$(cnt 'EMU CAIDA' $SL) dano=$(cnt 'EMU DANO' $SL) adentro=$(cnt 'EMU ADENTRO' $SL) muerte=$(cnt 'EMU MUERTE' $SL) vueloOffAlto=$VOFF parcial=$(cnt 'EMU PARCIAL' $SL) hielo="$(grep -a 'HIELO golpes' $SL | tail -1 | grep -o 'golpes=[0-9]* agua=[0-9]* colocados=[0-9]*' | tr ' ' ',')" biomas=$BIOMAS"
echo "$LINE | resultado: $RESULT | alPrinter: $CHK | final: $FCHK" >> $E/out/results.txt
echo "$LINE"
(cd $E/out && tar czf $TAG.tgz --exclude='*.png' $TAG 2>/dev/null; tar czf $TAG-png.tgz $TAG/*.png 2>/dev/null)
