#!/bin/bash
# Banco flujo r1: dos /wild cierran la GUI y no teletransportan
DESC='dos /wild cierran la GUI y no teletransportan'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  fail-first-n: 2
EOF_OVR
)
