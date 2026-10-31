#!/bin/bash
# Banco flujo r2: los 2 primeros /f create responden nombre tomado en castellano
DESC='los 2 primeros /f create responden nombre tomado en castellano'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
faction:
  taken-first-n: 2
  msg-tag-taken: "&cEse nombre de faccion ya esta en uso, elegi otro."
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['create_ok']==1
EOF_CHK
)
