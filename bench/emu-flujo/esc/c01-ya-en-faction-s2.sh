#!/bin/bash
# Banco flujo r1: la cuenta ya esta en una faction
DESC='la cuenta ya esta en una faction'
EXPECT='FAIL:ya esta en una faction'
N=55
LAG=0
JIT=0
MIN=20
CHK=$(cat <<'EOF_CHK'
m['create_cmd']==0
m['wild_cmd']==0
m['claim_cmd']==0
EOF_CHK
)
SRV_CMDS=$(cat <<'EOF_SRV_CMDS'
emu join TestBot Lobos
EOF_SRV_CMDS
)
SEED=flujo2-c01-ya-en-faction
