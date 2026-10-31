#!/bin/bash
# Manejo del cliente por xdotool. Uso: drv.sh cmd "/ctb select" | key Right [..] | keydown K | keyup K | shot RUTA.png | chat [n]
export DISPLAY=:99
W=$(xdotool search --name "Minecraft" 2>/dev/null | head -1)
case "$1" in
  cmd) xdotool windowactivate --sync $W 2>/dev/null; xdotool key --window $W t; sleep 0.7; xdotool type --delay 30 "$2"; sleep 0.3; xdotool key Return; sleep 1;;
  esc) xdotool key Escape;;
  shiftenter) xdotool windowactivate --sync $W 2>/dev/null; xdotool keydown Shift_L; sleep 0.3; xdotool keydown Return; sleep 0.2; xdotool keyup Return; sleep 0.2; xdotool keyup Shift_L;;
  key) shift; xdotool windowactivate --sync $W 2>/dev/null; for k in "$@"; do xdotool keydown $k; sleep 0.15; xdotool keyup $k; sleep 0.45; done;;
  keydown) xdotool keydown $2;; keyup) xdotool keyup $2;;
  shot) import -window root "$2" 2>/dev/null; echo "$2";;
  chat) grep -a '\[CHAT\]' /home/user/cli/logs/latest.log | tail -${2:-15} | sed 's/.*\[CHAT\] //; s/\xc2\xa7.//g; s/§.//g' | cut -c1-260;;
esac
