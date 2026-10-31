#!/bin/bash
# Banco flujo r1: parar justo despues de mandar /f create (respuesta 8 s tarde) y retomar
DESC='parar justo despues de mandar /f create (respuesta 8 s tarde) y retomar'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
faction:
  create-msg-delay-ticks: 160
EOF_OVR
)
ACT=$(cat <<'EOF_ACT'
log=SEND /f create|stop
t=0+12|resume
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['create_cmd']==1
EOF_CHK
)
BOT_CMDS=$(cat <<'EOF_BOT_CMDS'
/cane config set autosetup.chatWindowTicks 100
EOF_BOT_CMDS
)
SEED=flujo2-c07-corte-tras-create
