#!/bin/bash
# Banco flujo r1: sin chunk busters
DESC='sin chunk busters'
EXPECT='FAIL:faltan chunk busters: tenes 0'
N=0
LAG=0
JIT=0
MIN=20
CHK=$(cat <<'EOF_CHK'
m['wild_cmd']==0
m['create_cmd']==0
EOF_CHK
)
SEED=flujo2-e01-busters0
