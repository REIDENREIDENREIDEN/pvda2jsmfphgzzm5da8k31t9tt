#!/bin/bash
# Banco flujo r1: parar despues del claim y usar /cane preparar nuevo (la cuenta ya tiene la faction del bot)
DESC='parar despues del claim y usar /cane preparar nuevo (la cuenta ya tiene la faction del bot)'
EXPECT='FAIL:ya esta en una faction'
N=55
LAG=0
JIT=0
MIN=20
ACT=$(cat <<'EOF_ACT'
log=STEP CLAIM_VERIFY -> FLY|stop
t=0+3|nuevo
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['create_ok']==1
m['claim_ok']==1
EOF_CHK
)
SEED=flujo2-c08-nuevo-con-faction
