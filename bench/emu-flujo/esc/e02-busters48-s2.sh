#!/bin/bash
# Banco flujo r1: 48 chunk busters (falta 1)
DESC='48 chunk busters (falta 1)'
EXPECT='FAIL:tenes 48 y hacen falta 49'
N=48
LAG=0
JIT=0
MIN=20
CHK=$(cat <<'EOF_CHK'
m['wild_cmd']==0
m['create_cmd']==0
EOF_CHK
)
SEED=flujo2-e02-busters48
