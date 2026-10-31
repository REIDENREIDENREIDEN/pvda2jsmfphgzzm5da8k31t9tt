#!/bin/bash
# Banco flujo r1: los 2 primeros /fly no hacen nada
DESC='los 2 primeros /fly no hacen nada'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
fly:
  silent-fail-first-n: 2
EOF_OVR
)
