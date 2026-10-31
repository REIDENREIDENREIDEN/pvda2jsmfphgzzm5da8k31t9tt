#!/bin/bash
# Banco flujo r1: parar y retomar en /wild, subiendo al warp, en los busters y en la esquina
DESC='parar y retomar en /wild, subiendo al warp, en los busters y en la esquina'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
OVR=$(cat <<'EOF_OVR'
wild:
  gui-open-delay-ticks: 40
EOF_OVR
)
ACT=$(cat <<'EOF_ACT'
log=SEND /wild|stop
t=0+6|resume
log=STEP FLY -> WARP+2|stop
t=0+6|resume
log=Chunk buster 30/49|stop
t=0+6|resume
log=STEP VERIFY -> CORNER+1|stop
t=0+6|resume
EOF_ACT
)
SEED=flujo2-g02-parar-4-veces
