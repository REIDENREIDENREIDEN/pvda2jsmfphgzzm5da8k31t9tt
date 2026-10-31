#!/bin/bash
# Banco flujo r1: sin dinero para /f claim 5
DESC='sin dinero para /f claim 5'
EXPECT='FAIL:dinero'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
claim:
  cost-per-chunk: 1000.0
money:
  start: 5000.0
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['claim_ok']==0
m['consumidos']==0
m['fly_cmd']==0
EOF_CHK
)
SEED=flujo2-c06-claim-sin-dinero
