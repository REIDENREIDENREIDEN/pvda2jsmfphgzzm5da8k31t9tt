#!/bin/bash
# Banco flujo r2: kick justo despues del primer /ci (inventario ya borrado) y reconecta
DESC='kick justo despues del primer /ci (inventario ya borrado) y reconecta'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
OVR=$(cat <<'EOF_OVR'
fly:
  keep-on-rejoin: true
EOF_OVR
)
ACT=$(cat <<'EOF_ACT'
log=SEND /ci|kick
log= STOP |reconnect
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['create_cmd']==1
m['claim_cmd']==1
m.get('busters_final')==0
EOF_CHK
)
