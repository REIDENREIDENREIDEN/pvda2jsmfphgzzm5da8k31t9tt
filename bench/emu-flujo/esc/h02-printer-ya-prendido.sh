#!/bin/bash
# Banco flujo r1: printer ya prendido antes de empezar
DESC='printer ya prendido antes de empezar'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
printer:
  start-on: true
EOF_OVR
)
