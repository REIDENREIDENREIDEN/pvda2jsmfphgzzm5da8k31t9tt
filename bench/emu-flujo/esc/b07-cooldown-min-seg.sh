#!/bin/bash
# Banco flujo r1: cooldown de /wild ya activo (75 s) con formato "1m 15s"
DESC='cooldown de /wild ya activo (75 s) con formato 1m 15s'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  initial-cooldown-seconds: 75
  msg-cooldown: "&cYou must wait %m%m %r%s before using /wild again."
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_cmd']<=8
EOF_CHK
)
