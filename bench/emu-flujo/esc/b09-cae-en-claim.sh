#!/bin/bash
# Banco flujo r1: los 2 primeros /wild caen DENTRO de un claim ajeno (mapa limpio salvo la celda del jugador)
DESC='los 2 primeros /wild caen DENTRO de un claim ajeno (mapa limpio salvo la celda del jugador)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  land-in-enemy-first-n: 2
EOF_OVR
)
CHK=$(cat <<'EOF_CHK'
m['wild_tp']>=3
EOF_CHK
)
