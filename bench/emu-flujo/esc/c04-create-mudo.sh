#!/bin/bash
# Banco flujo r1: el primer /f create crea la faction pero no responde nada
DESC='el primer /f create crea la faction pero no responde nada'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
faction:
  create-silent-first-n: 1
EOF_OVR
)
