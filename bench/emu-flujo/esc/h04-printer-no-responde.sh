#!/bin/bash
# Banco flujo r1: printer no hace nada
DESC='printer no hace nada'
EXPECT='FAIL:printer'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
printer:
  never: true
EOF_OVR
)
