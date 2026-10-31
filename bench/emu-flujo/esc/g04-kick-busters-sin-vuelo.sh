#!/bin/bash
# Banco flujo r1: kick en los busters, reconecta SIN vuelo (cae)
DESC='kick en los busters, reconecta SIN vuelo (cae)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
ACT=$(cat <<'EOF_ACT'
log=Chunk buster 20/49|kick
log= STOP |reconnect
EOF_ACT
)
