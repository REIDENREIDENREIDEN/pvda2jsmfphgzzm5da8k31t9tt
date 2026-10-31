#!/bin/bash
# Banco flujo r2: kick apenas llega el /wild (antes de /f map) y reconecta
DESC='kick apenas llega el /wild (antes de /f map) y reconecta'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
ACT=$(cat <<'EOF_ACT'
log=STEP WILD -> FMAP|kick
log= STOP |reconnect
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['create_cmd']==1
m['claim_cmd']==1
EOF_CHK
)
