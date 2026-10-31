#!/bin/bash
# Banco flujo r2: /wild con warmup: Please wait 3 seconds, teleporting you... (3 s hasta el tp)
DESC='/wild con warmup: Please wait 3 seconds, teleporting you... (3 s hasta el tp)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  delay-ticks: 60
  enemy-chance: 0.0
  msg-teleporting: "&aPlease wait 3 seconds, teleporting you to a random location..."
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_cmd']<=3
EOF_CHK
)
