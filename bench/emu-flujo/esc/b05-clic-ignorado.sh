#!/bin/bash
# Banco flujo r1: los 2 primeros clics en la perla no hacen nada
DESC='los 2 primeros clics en la perla no hacen nada'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  ignore-first-clicks: 2
EOF_OVR
)
