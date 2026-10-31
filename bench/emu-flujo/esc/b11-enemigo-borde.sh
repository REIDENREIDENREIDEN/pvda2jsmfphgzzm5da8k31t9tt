#!/bin/bash
# Banco flujo r2: 4 /wild seguidos con un claim enemigo en el BORDE del /f map (8 chunks)
DESC='4 /wild seguidos con un claim enemigo en el BORDE del /f map (8 chunks)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  enemy-first-n: 4
  enemy-min-chunks: 8
  enemy-max-chunks: 8
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_tp']>=5
m['create_ok']==1
EOF_CHK
)
