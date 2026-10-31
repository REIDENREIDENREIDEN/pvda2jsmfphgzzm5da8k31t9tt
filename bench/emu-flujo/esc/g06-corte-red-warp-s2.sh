#!/bin/bash
# Banco flujo r1: corte de red subiendo al warp, reconecta (vuelo conservado)
DESC='corte de red subiendo al warp, reconecta (vuelo conservado)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
OVR=$(cat <<'EOF_OVR'
fly:
  keep-on-rejoin: true
EOF_OVR
)
ACT=$(cat <<'EOF_ACT'
log=STEP FLY -> WARP+3|netcut
log= STOP |reconnect
EOF_ACT
)
SEED=flujo2-g06-corte-red-warp
