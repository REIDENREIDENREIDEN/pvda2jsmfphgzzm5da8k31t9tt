#!/bin/bash
# Banco flujo r1: GUI de /wild tarda 3 s en abrir y la perla cambia de slot
DESC='GUI de /wild tarda 3 s en abrir y la perla cambia de slot'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  gui-open-delay-ticks: 60
  pearl-slot-random: true
  enemy-first-n: 2
EOF_OVR
)
SEED=flujo2-b03-gui-lenta-slot
