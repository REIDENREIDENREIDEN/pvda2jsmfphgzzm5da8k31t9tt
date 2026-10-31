#!/bin/bash
# Banco flujo r1: el vuelo se corta una vez a los 45 s (combat tag) y /fly lo devuelve
DESC='el vuelo se corta una vez a los 45 s (combat tag) y /fly lo devuelve'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
fly:
  drop-after-seconds: 45
EOF_OVR
)
SEED=flujo2-d03-fly-cortado
