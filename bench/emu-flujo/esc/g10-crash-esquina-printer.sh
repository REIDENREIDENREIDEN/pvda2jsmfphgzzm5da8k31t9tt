#!/bin/bash
# Banco flujo r2: printer ya prendido + crash en la esquina antes de /ci y se reabre
DESC='printer ya prendido + crash en la esquina antes de /ci y se reabre'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
OVR=$(cat <<'EOF_OVR'
printer:
  start-on: true
EOF_OVR
)
ACT=$(cat <<'EOF_ACT'
log=STEP CORNER -> CI|crash
t=0|reconnect
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['create_cmd']==1
m['claim_cmd']==1
EOF_CHK
)
