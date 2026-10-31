#!/bin/bash
# Banco flujo r1: 3 /wild seguidos con factions cerca
DESC='3 /wild seguidos con factions cerca'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  enemy-first-n: 3
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_tp']>=4
m['claim_ok']==1
EOF_CHK
)
