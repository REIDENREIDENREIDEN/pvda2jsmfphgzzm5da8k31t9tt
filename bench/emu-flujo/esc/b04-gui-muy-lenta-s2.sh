#!/bin/bash
# Banco flujo r1: GUI de /wild tarda 7 s (mas que el timeout de 5 s del bot)
DESC='GUI de /wild tarda 7 s (mas que el timeout de 5 s del bot)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  gui-open-delay-ticks: 140
  cooldown-seconds: 3
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_cmd']<=6
EOF_CHK
)
SEED=flujo2-b04-gui-muy-lenta
