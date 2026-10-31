#!/bin/bash
# Banco flujo r2: cooldown de /wild (70 s) con texto sin cooldown/wait: You cannot use /wild for another 1m 10s
DESC='cooldown de /wild (70 s) con texto sin cooldown/wait: You cannot use /wild for another 1m 10s'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  initial-cooldown-seconds: 70
  msg-cooldown: "&cYou cannot use /wild for another %m%m %r%s!"
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_cmd']<=8
EOF_CHK
)
