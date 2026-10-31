#!/bin/bash
# Banco flujo r1: mensaje de fin "Chunk Buster has finished clearing" (parecido al de colocado) + ping 200
DESC='mensaje de fin Chunk Buster has finished clearing (parecido al de colocado) + ping 200'
EXPECT='DONE'
N=55
LAG=100
JIT=20
MIN=20
OVR=$(cat <<'EOF_OVR'
buster:
  msg-done: "&aChunk Buster has finished clearing chunk %x%, %z%!"
EOF_OVR
)
SEED=flujo2-e07-fin-parece-ok
