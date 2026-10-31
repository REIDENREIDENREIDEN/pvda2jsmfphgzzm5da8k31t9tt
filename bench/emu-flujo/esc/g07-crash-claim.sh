#!/bin/bash
# Banco flujo r1: el cliente se cierra (crash) 1 s despues de mandar /f claim y se reabre
DESC='el cliente se cierra (crash) 1 s despues de mandar /f claim y se reabre'
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
log=SEND /f claim+1|crash
t=0|reconnect
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['claim_ok']==1
m['create_cmd']==1
EOF_CHK
)
