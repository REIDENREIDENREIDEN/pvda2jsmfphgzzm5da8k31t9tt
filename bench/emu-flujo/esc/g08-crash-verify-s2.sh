#!/bin/bash
# Banco flujo r1: crash al empezar la verificacion final y se reabre
DESC='crash al empezar la verificacion final y se reabre'
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
log=STEP BUSTERS -> VERIFY|crash
t=0|reconnect
EOF_ACT
)
SEED=flujo2-g08-crash-verify
