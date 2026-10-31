#!/bin/bash
# Banco flujo r1: 8 /wild seguidos con factions cerca y cooldown de /wild de 15 s
DESC='8 /wild seguidos con factions cerca y cooldown de /wild de 15 s'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
OVR=$(cat <<'EOF_OVR'
wild:
  enemy-first-n: 8
  cooldown-seconds: 15
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_tp']>=9
EOF_CHK
)
SEED=flujo2-b02-enemigos8-cd15
