#!/bin/bash
# Banco flujo r1: claim, setwarp y buster sin ningun mensaje (formato desconocido)
DESC='claim, setwarp y buster sin ningun mensaje (formato desconocido)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
claim:
  silent: true
warp:
  silent: true
buster:
  silent: true
EOF_OVR
)
SEED=flujo2-e04-mensajes-mudos
