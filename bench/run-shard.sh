#!/bin/bash
# Corre una tanda de escenarios, uno detras de otro, con los scripts de los bancos sin cambios.
# Uso: run-shard.sh terreno|flujo JAR "esc1 esc2 ..."
# Cada corrida deja una linea RES en OUT/results.txt:
#   terreno: la de emu/run.sh (done=1 = preparacion DONE)
#   flujo:   RES ESC pasa=0|1 done=0|1 prep=S dur=S | VEREDICTO ... | RESULTADO ...   (de emu-flujo/eval.py)
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BENCH=$1; JAR=$(readlink -f "$2"); ITEMS=$3
T0=$(date +%s); BUDGET=${BUDGET_MIN:-320}
# sin_tiempo MIN: true si el escenario siguiente ya no entra en el presupuesto del job
sin_tiempo() { [ $(( ($(date +%s) - T0) / 60 + $1 )) -gt $BUDGET ]; }
cleanup() { bash /home/user/banco/cli.sh stop >/dev/null 2>&1; pkill -f '[l]ag.py'; bash /home/user/emu/srv.sh stop >/dev/null 2>&1; bash /home/user/emu-flujo/srv.sh stop >/dev/null 2>&1; }
case "$BENCH" in
  terreno)
    O=/home/user/emu/out; mkdir -p $O
    for t in $ITEMS; do
      if sin_tiempo 25; then echo "RES $t ERROR=sin-tiempo" >> $O/results.txt; continue; fi
      echo "[shard $(date +%T)] terreno $t"
      line=$(python3 "$ROOT/tools/plan.py" cmd terreno "$t" "$JAR") || { echo "RES $t ERROR=plan" >> $O/results.txt; continue; }
      echo "$line" > $O/cmd-$t.txt
      timeout 25m bash -c "$line" || echo "[shard] $t salio con $?"
      grep -q "^RES $t " $O/results.txt 2>/dev/null || echo "RES $t ERROR=timeout-o-sin-RES" >> $O/results.txt
      cleanup
    done ;;
  flujo)
    E=/home/user/emu-flujo; O=$E/out; mkdir -p $O
    bash $E/srv.sh build > $O/build.log 2>&1 || { for e in $ITEMS; do echo "RES $e ERROR=build" >> $O/results.txt; done; exit 1; }
    for e in $ITEMS; do
      if sin_tiempo 35; then echo "RES $e ERROR=sin-tiempo" >> $O/results.txt; continue; fi
      echo "[shard $(date +%T)] flujo $e"
      timeout 35m bash $E/flujo.sh $E/esc/$e.sh "$JAR" || echo "[shard] $e salio con $?"
      V=$O/$e/veredicto.txt
      if [ -s "$V" ]; then
        python3 - "$e" "$V" "$O/$e/duracion.txt" >> $O/results.txt <<'PY'
import json, sys
e, v, d = sys.argv[1:4]
t = open(v, encoding='utf-8', errors='replace').read().splitlines()
ver = next((l for l in t if l.startswith('VEREDICTO')), 'VEREDICTO ?')
res = next((l for l in t if l.startswith('RESULTADO')), 'RESULTADO ?')
m = next((json.loads(l[9:]) for l in t if l.startswith('METRICAS ')), {})
try: dur = open(d).read().strip()
except OSError: dur = '?'
print('RES %s pasa=%d done=%d prep=%s dur=%s wild=%s busters=%s | %s | %s' % (
    e, ver.startswith('VEREDICTO PASA'), res.startswith('RESULTADO DONE'), m.get('prep_s', '?'), dur,
    m.get('wild_cmd', '?'), m.get('consumidos', '?'), ver[:300], res[:200]))
PY
      else
        echo "RES $e ERROR=sin-veredicto" >> $O/results.txt
      fi
      cleanup
    done ;;
  *) echo "bench desconocido: $BENCH"; exit 2 ;;
esac
cleanup
grep '^RES ' $O/results.txt
