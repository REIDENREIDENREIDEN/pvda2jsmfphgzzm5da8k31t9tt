#!/bin/bash
# Banco flujo r2: ping ~250 ms con jitter y kick en la mitad de los busters (reconecta con vuelo)
DESC='ping ~250 ms con jitter y kick en la mitad de los busters (reconecta con vuelo)'
EXPECT='DONE'
N=55
LAG=125
JIT=40
MIN=25
OVR=$(cat <<'EOF_OVR'
fly:
  keep-on-rejoin: true
EOF_OVR
)
ACT=$(cat <<'EOF_ACT'
log=Chunk buster 24/49|kick
log= STOP |reconnect
EOF_ACT
)
CHK=$(cat <<'EOF_CHK'
m['create_cmd']==1
m['claim_cmd']==1
EOF_CHK
)
