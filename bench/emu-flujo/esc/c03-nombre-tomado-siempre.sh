#!/bin/bash
# Banco flujo r1: todo /f create responde nombre tomado
DESC='todo /f create responde nombre tomado'
EXPECT='FAIL:nombre de faction libre'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
faction:
  taken-first-n: 99
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['claim_cmd']==0
m['consumidos']==0
m['create_cmd']<=6
EOF_CHK
)
