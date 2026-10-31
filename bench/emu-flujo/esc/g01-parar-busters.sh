#!/bin/bash
# Banco flujo r1: parar a mitad de los busters y retomar
DESC='parar a mitad de los busters y retomar'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
ACT=$(cat <<'EOF_ACT'
log=Chunk buster 12/49|stop
t=0+8|resume
EOF_ACT
)
