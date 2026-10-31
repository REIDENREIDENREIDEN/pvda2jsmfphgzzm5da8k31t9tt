#!/bin/bash
# Banco flujo r2: parar al empezar la verificacion final y retomar
DESC='parar al empezar la verificacion final y retomar'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
ACT=$(cat <<'EOF_ACT'
log=STEP BUSTERS -> VERIFY|stop
t=0+5|resume
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['create_cmd']==1
EOF_CHK
)
