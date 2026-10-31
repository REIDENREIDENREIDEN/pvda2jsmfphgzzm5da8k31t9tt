#!/bin/bash
# Banco flujo r1: /wild cae sobre nieve (capa de nieve de bioma frio)
DESC='/wild cae sobre nieve (capa de nieve de bioma frio)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  force-snow: true
EOF_OVR
)
SEED=flujo2-a06-nieve
