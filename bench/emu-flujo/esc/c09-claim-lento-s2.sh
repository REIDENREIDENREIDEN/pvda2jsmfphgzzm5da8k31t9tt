#!/bin/bash
# Banco flujo r1: /f claim 5 se procesa de a 1 chunk cada tick (81 ticks = 4 s) y confirma al final
DESC='/f claim 5 se procesa de a 1 chunk cada tick (81 ticks = 4 s) y confirma al final'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
claim:
  chunks-per-tick: 1
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['claim_ok']==1
EOF_CHK
)
SEED=flujo2-c09-claim-lento
