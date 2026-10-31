#!/bin/bash
# Banco flujo r1: cooldown de /wild ya activo (20 s) con texto en castellano
DESC='cooldown de /wild ya activo (20 s) con texto en castellano'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  initial-cooldown-seconds: 20
  msg-cooldown: "&cDebes esperar %s segundos para volver a usar /wild."
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_cmd']<=5
EOF_CHK
)
SEED=flujo2-b08-cooldown-es
