#!/bin/bash
# Banco flujo r1: /ci pide confirmacion (el segundo borra)
DESC='/ci pide confirmacion (el segundo borra)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
ci:
  confirm: true
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m.get('busters_final')==0
EOF_CHK
)
SEED=flujo2-h01-ci-confirmacion
