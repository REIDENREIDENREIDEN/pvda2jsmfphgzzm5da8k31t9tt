#!/bin/bash
# Banco flujo r1: /wild cae sobre nieve + ping ~200 ms
DESC='/wild cae sobre nieve + ping ~200 ms'
EXPECT='DONE'
N=55
LAG=100
JIT=20
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  force-snow: true
EOF_OVR
)
