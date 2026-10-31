#!/bin/bash
# Banco flujo r1: printer cambia pero no confirma nada
DESC='printer cambia pero no confirma nada'
EXPECT='FAIL:printer'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
printer:
  silent: true
EOF_OVR
)
