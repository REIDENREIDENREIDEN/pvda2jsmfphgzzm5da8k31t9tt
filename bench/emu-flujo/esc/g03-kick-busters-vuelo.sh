#!/bin/bash
# Banco flujo r1: kick en los busters, reconecta (el server conserva el vuelo)
DESC='kick en los busters, reconecta (el server conserva el vuelo)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
OVR=$(cat <<'EOF_OVR'
fly:
  keep-on-rejoin: true
EOF_OVR
)
ACT=$(cat <<'EOF_ACT'
log=Chunk buster 15/49|kick
log= STOP |reconnect
EOF_ACT
)
