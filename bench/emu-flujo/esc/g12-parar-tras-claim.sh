#!/bin/bash
# Banco flujo r2: parar justo despues de mandar /f claim (claim lento, 1 chunk por tick) y retomar
DESC='parar justo despues de mandar /f claim (claim lento, 1 chunk por tick) y retomar'
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
ACT=$(cat <<'EOF_ACT'
log=SEND /f claim|stop
t=0+6|resume
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['claim_cmd']==1
m['create_cmd']==1
EOF_CHK
)
