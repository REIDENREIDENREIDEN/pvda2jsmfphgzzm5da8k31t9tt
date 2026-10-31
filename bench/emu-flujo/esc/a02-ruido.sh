#!/bin/bash
# Banco flujo r1: chat muy activo (broadcasts, jugadores con wait/esper/created/claimed/cooldown cada 2.5 s)
DESC='chat muy activo (broadcasts, jugadores con wait/esper/created/claimed/cooldown cada 2.5 s)'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
noise:
  period-ticks: 50
  lines:
    - "&7[&bServer&7] &fVota con /vote y recibi recompensas!"
    - "&8[&c&lKOTH&8] &fEl KOTH empieza en 5 minutos, wait at spawn."
    - "&7Pepe&8: &fwait 3 sec"
    - "&7Juan&8: &fesperen 10 min que vuelvo"
    - "&7Ana&8: &fjust claimed 20 chunks lol"
    - "&7Luis&8: &fquien vende chunk busters? cooldown 5 s"
    - "&ePepe created a new faction &aWolves"
    - "&7[&6Envoy&7] &fCrates dropping in 30 seconds!"
EOF_OVR
)
