#!/bin/bash
# Banco flujo r2: la cuenta ya esta en una faction y /f show tiene otro formato (Leader/Members/Power)
DESC='la cuenta ya esta en una faction y /f show tiene otro formato (Leader/Members/Power)'
EXPECT='FAIL:ya esta en una faction'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
faction:
  show-lines:
    - "&6---- &aLobos &6----"
    - "&6Leader: &fCapitan"
    - "&6Members (2): &fCapitan, TestBot"
    - "&6Power: &e10/20"
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['claim_cmd']==0
m['create_ok']==0
m['setwarp_cmd']==0
EOF_CHK
)
SRV_CMDS=$(cat <<'EOF_SRV_CMDS'
emu join TestBot Lobos
EOF_SRV_CMDS
)
