#!/bin/bash
# Banco flujo r1: el vuelo se corta a los 60 s y /fly queda negado
DESC='el vuelo se corta a los 60 s y /fly queda negado'
EXPECT='FAIL:vuelo'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
fly:
  drop-after-seconds: 60
  deny-after-drop: true
EOF_OVR
)
