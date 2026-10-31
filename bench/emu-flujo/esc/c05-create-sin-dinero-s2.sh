#!/bin/bash
# Banco flujo r1: sin dinero para /f create
DESC='sin dinero para /f create'
EXPECT='FAIL:create'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
faction:
  create-cost: 1000000000
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['claim_cmd']==0
m['consumidos']==0
EOF_CHK
)
SEED=flujo2-c05-create-sin-dinero
