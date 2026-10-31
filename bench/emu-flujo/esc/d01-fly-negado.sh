#!/bin/bash
# Banco flujo r1: /fly sin permiso
DESC='/fly sin permiso'
EXPECT='FAIL:sin permiso'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
fly:
  deny: true
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['setwarp_cmd']==0
m['consumidos']==0
EOF_CHK
)
