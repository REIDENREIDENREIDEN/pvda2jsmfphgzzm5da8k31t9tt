#!/bin/bash
# Banco flujo r3: entra lava al piso del hueco (linea de la esquina) despues de verificar los chunks
DESC='lava en el piso del hueco sobre la linea de la esquina despues de bustear'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
OVR=''
ACT=$(cat <<'EOF_ACT'
log=STEP BUSTERS -> VERIFY|con:emu lava TestBot
EOF_ACT
)
