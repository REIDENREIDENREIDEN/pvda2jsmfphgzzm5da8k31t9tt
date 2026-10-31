#!/bin/bash
# Banco flujo r1: cooldown real del buster 8 s (el bot asume 5) con el texto del usuario
DESC='cooldown real del buster 8 s (el bot asume 5) con el texto del usuario'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=25
OVR=$(cat <<'EOF_OVR'
buster:
  cooldown-seconds: 8
  msg-cooldown: "&cTenés un cooldown de %s segundos para poder placear otro."
EOF_OVR
)
SEED=flujo2-e06-cooldown8
