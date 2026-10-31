#!/bin/bash
# Banco flujo r1: todos los mensajes en castellano
DESC='todos los mensajes en castellano'
EXPECT='DONE'
N=55
LAG=0
JIT=0
MIN=20
OVR=$(cat <<'EOF_OVR'
wild:
  msg-teleporting: "&aTeletransportandote a un lugar aleatorio..."
  msg-teleported: "&aFuiste teletransportado a &e%x%, %y%, %z%&a."
  msg-cooldown: "&cDebes esperar %s segundos para volver a usar /wild."
faction:
  msg-not-in-faction: "&cNo perteneces a ninguna faccion."
  msg-must-leave: "&cPrimero sal de tu faccion actual."
  msg-tag-taken: "&cEse nombre ya existe."
  msg-created: "&eCreaste la faccion &a%name%&e."
claim:
  msg-ok: "&aReclamaste &e%count% &achunks para &e%name%&a."
warp:
  msg-set: "&aWarp &e%name% &acreado en tu ubicacion."
fly:
  msg-on: "&aModo vuelo activado."
buster:
  msg-placed: "&a¡Chunk Buster colocado! Limpiando el chunk &e%x%, %z%&a..."
  msg-cooldown: "&cTenés un cooldown de %s segundos para poder placear otro."
  msg-done: "&aEl chunk &e%x%, %z% &aquedo vacio."
printer:
  msg-on: "&aYou have enabled printer mode."
EOF_OVR
)
