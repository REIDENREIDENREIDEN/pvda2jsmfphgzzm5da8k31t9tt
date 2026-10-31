#!/bin/bash
# Banco flujo r1: 49 busters exactos y kick justo despues de que el server acepta un buster
DESC='49 busters exactos y kick justo despues de que el server acepta un buster'
EXPECT='DONE'
N=49
LAG=0
JIT=0
MIN=25
OVR=$(cat <<'EOF_OVR'
fly:
  keep-on-rejoin: true
buster:
  kick-on-place-n: 12
EOF_OVR
)
ACT=$(cat <<'EOF_ACT'
log= STOP |reconnect
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m.get('busters_final')==0
EOF_CHK
)
SEED=flujo2-g05-kick-al-colocar-49
