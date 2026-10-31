#!/bin/bash
# (VM) Banco 'flujo' ronda 1: una corrida completa del AutoSetup con el cliente Forge 1.8.9 real (Xvfb) contra
# emu-flujo (Paper 1.8.8 + FactionsEmu con fallas inyectadas) detras del proxy lag.py (ping simulado).
# Uso: flujo.sh ESCENARIO.sh JAR
# El escenario (bash) puede definir:
#   SEED, N (busters), OVR (yaml que pisa config.yml del plugin), SRV_CMDS (consola, una por linea, antes de empezar),
#   LAG/JIT (ms por sentido), BOT_CMDS (chat del cliente antes de empezar), MIN (minutos maximo),
#   ACT (lineas "disparador|accion"), EXPECT (DONE | FAIL:regex), CHK (condiciones python extra, una por linea, sobre m[...]).
# Disparadores: t=SEG (desde /cane preparar) | log=REGEX (autosetup.log, lineas nuevas desde la accion anterior) |
#   srv=REGEX (server.log, lineas nuevas); "+SEG" al final espera SEG segundos mas ("log=STEP WARP+3").
# Acciones: stop | resume | nuevo | kick | netcut | crash | reconnect | con:CMD | cmd:CHAT
ESC=$(readlink -f "$1"); JAR=$(readlink -f "$2"); NAME=$(basename "$ESC" .sh)
E=/home/user/emu-flujo; B=/home/user/banco; S=/home/user/emu-srv; C=/home/user/cli; O=$E/out/$NAME
SEED=flujo-$NAME; N=55; OVR=""; SRV_CMDS=""; LAG=0; JIT=0; ACT=""; EXPECT=DONE; CHK=""; MIN=20; BOT_CMDS=""; DESC=""
. "$ESC"
mkdir -p $O; rm -rf $O/*
AL=$C/logs/canebot-autosetup.log
srv() { bash $E/srv.sh "$@"; }
say() { echo "[$NAME $(date +%H:%M:%S)] $*"; }
joins() { grep -ac 'TestBot\[.*logged in with entity' $S/server.log 2>/dev/null; }
waitjoin() { for i in $(seq 1 240); do [ "$(joins)" -gt "$1" ] && return 0; sleep 2; done; return 1; }
chat() { srv con "emu close TestBot" 0.2 >/dev/null; sleep 0.2; bash $B/drv.sh cmd "$1"; }
printf 'DESC=%s\nEXPECT=%s\nSEED=%s N=%s LAG=%s JIT=%s\nACT:\n%s\nCHK:\n%s\n' "$DESC" "$EXPECT" "$SEED" "$N" "$LAG" "$JIT" "$ACT" "$CHK" > $O/escenario.txt

bash $B/cli.sh stop >/dev/null 2>&1; pkill -f '[l]ag.py'; srv stop >/dev/null; srv reset >/dev/null
mkdir -p $S/plugins/FactionsEmu; cp $E/plugin/res/config.yml $S/plugins/FactionsEmu/config.yml
printf '%s\n' "$OVR" > $S/plugins/FactionsEmu/override.yml; cp $S/plugins/FactionsEmu/override.yml $O/override.yml
srv start "$SEED" > $O/srv-start.txt || { say NO-ARRANCA; echo "VEREDICTO FALLA-BANCO no arranco el servidor" > $O/veredicto.txt; exit 1; }
rm -f /tmp/lag-cut; setsid nohup python3 $E/lag.py $LAG $JIT > $O/lag.log 2>&1 &
sleep 1
rm -f $AL $C/logs/canebot-autosetup.1.log $C/config/canetowerbot/autosetup*.properties
# Ajustes del bot por defecto en cada escenario (BOT_CMDS de un escenario anterior no se arrastran).
rm -f $C/config/canetowerbot/settings.json $C/config/canetowerbot/live-main.json $C/config/canetowerbot-progress.properties
bash $B/cli.sh start "$JAR" TestBot >/dev/null
waitjoin 0 || { say NO-ENTRO; tail -40 /tmp/client.log > $O/client-tail.txt; echo "VEREDICTO FALLA-BANCO no entro el cliente" > $O/veredicto.txt; exit 1; }
sleep 25
[ "$N" -gt 0 ] && srv con "cbgive TestBot $N" 2 >/dev/null
while IFS= read -r c; do [ -n "$c" ] && srv con "$c" 1 >/dev/null; done <<< "$SRV_CMDS"
bash $B/drv.sh cmd "/cane config set autosetup.capture true"; sleep 1
while IFS= read -r c; do [ -n "$c" ] && { bash $B/drv.sh cmd "$c"; sleep 1; }; done <<< "$BOT_CMDS"
bash $B/drv.sh shot $O/0-antes.png >/dev/null
mapfile -t ACTS < <(printf '%s\n' "$ACT" | sed '/^\s*$/d')
say "inicio ($DESC) acciones=${#ACTS[@]}"
T0=$(date +%s); END=$((T0 + MIN * 60))
bash $B/drv.sh cmd "/cane preparar"
ai=0; amark=0; smark=$(wc -l < $S/server.log); fired=""; k=0; holechk=""; stopseen=""; recon=0
while [ $(date +%s) -lt $END ]; do
  sleep 0.5; k=$((k+1)); now=$(date +%s); el=$((now - T0))
  [ $((k % 120)) = 0 ] && { say "$el s: $(grep -a 'STEP\|MSG' $AL 2>/dev/null | tail -1 | cut -c1-160)"; bash $B/drv.sh shot $O/t$el.png >/dev/null; }
  if [ -z "$holechk" ] && grep -aq 'STEP VERIFY -> CORNER' $AL 2>/dev/null; then
    holechk=1; srv con "emu check TestBot 3" 6 | grep -a 'CHECK' | tail -1 > $O/check-hueco.txt
  fi
  if [ $ai -lt ${#ACTS[@]} ]; then
    line=${ACTS[$ai]}; trig=${line%%|*}; act=${line#*|}
    wait=0; [[ "$trig" =~ ^(.*)\+([0-9]+)$ ]] && { trig=${BASH_REMATCH[1]}; wait=${BASH_REMATCH[2]}; }
    if [ -z "$fired" ]; then
      case "$trig" in
        t=*) [ $el -ge ${trig#t=} ] && fired=$now ;;
        log=*) tail -n +$((amark + 1)) $AL 2>/dev/null | grep -aEq -- "${trig#log=}" && fired=$now ;;
        srv=*) tail -n +$((smark + 1)) $S/server.log | grep -aEq -- "${trig#srv=}" && fired=$now ;;
      esac
    fi
    if [ -n "$fired" ] && [ $now -ge $((fired + wait)) ]; then
      say "accion $ai: $act (disparo: $trig a los $el s)"; echo "$el s accion $act ($trig)" >> $O/acciones.txt
      amark=$(wc -l < $AL 2>/dev/null || echo 0); smark=$(wc -l < $S/server.log)
      case "$act" in
        stop) chat "/cane preparar parar" ;;
        resume) sleep 2; chat "/cane preparar" ;;
        nuevo) sleep 2; chat "/cane preparar nuevo" ;;
        kick) srv con "kick TestBot Banco: kick de prueba" 1 >/dev/null ;;
        netcut) touch /tmp/lag-cut; sleep 2 ;;
        crash) pkill -9 -f '[n]et.minecraft.launchwrapper'; sleep 3 ;;
        reconnect)
          recon=$((recon + 1)); cp $C/logs/latest.log $O/cliente-$recon.log 2>/dev/null
          sleep 5; J=$(joins); bash $B/cli.sh start "$JAR" TestBot >/dev/null
          waitjoin $J || say "NO-RECONECTO"; sleep 20; chat "/cane preparar" ;;
        con:*) srv con "${act#con:}" 1 >/dev/null ;;
        cmd:*) chat "${act#cmd:}" ;;
      esac
      ai=$((ai + 1)); fired=""
      continue
    fi
  fi
  tail -n +$((amark + 1)) $AL 2>/dev/null | grep -aq ' DONE \| FAIL ' && break
  if [ $ai -ge ${#ACTS[@]} ] && tail -n +$((amark + 1)) $AL 2>/dev/null | grep -aq ' STOP '; then
    [ -z "$stopseen" ] && stopseen=$now; [ $now -ge $((stopseen + 5)) ] && break
  fi
done
say "fin a los $(( $(date +%s) - T0 )) s"
echo "$(( $(date +%s) - T0 ))" > $O/duracion.txt
sleep 1
srv con "emu check TestBot 3" 6 | grep -a 'CHECK' | tail -1 > $O/check.txt
bash $B/drv.sh shot $O/fin.png >/dev/null
chat "/cane stop"; sleep 2
cp $S/server.log $O/server.log; cp $C/logs/latest.log $O/cliente.log 2>/dev/null; cp $AL $O/autosetup.log 2>/dev/null
cp $C/config/canetowerbot/autosetup.properties $O/ 2>/dev/null
grep -a '\[CHAT\]' $O/cliente.log | sed 's/.*\[CHAT\] //' > $O/chat.txt
python3 $E/eval.py $O > $O/veredicto.txt 2>&1
cat $O/veredicto.txt | head -3
