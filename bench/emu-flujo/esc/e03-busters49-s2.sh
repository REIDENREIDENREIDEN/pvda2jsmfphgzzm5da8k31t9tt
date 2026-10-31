#!/bin/bash
# Banco flujo r1: exactamente 49 chunk busters
DESC='exactamente 49 chunk busters'
EXPECT='DONE'
N=49
LAG=0
JIT=0
MIN=20
CHK=$(cat <<'EOF_CHK'
m.get('busters_final')==0
EOF_CHK
)
SEED=flujo2-e03-busters49
