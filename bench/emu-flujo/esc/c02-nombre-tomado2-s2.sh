#!/bin/bash
# Banco flujo r1: los 2 primeros /f create responden nombre tomado
DESC='los 2 primeros /f create responden nombre tomado'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
faction:
  taken-first-n: 2
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['create_cmd']==3
EOF_CHK
)
SEED=flujo2-c02-nombre-tomado2
