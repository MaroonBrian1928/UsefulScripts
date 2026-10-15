#!/usr/bin/env bash
# drain-watch.sh — start before bed; samples into ~/.drain-watch.log for drain-diag.sh to
# read in the morning. Ctrl-C to stop.   Usage: ./drain-watch.sh [seconds, 10-86400, default 300]
#
# Samples only happen while the Mac is awake (this loop is paused during sleep), so gaps in
# the log are normal sleep; what you see is what the Mac was doing whenever it was awake.
# Format (tab-separated): epoch, local time + offset, power source + charge, (unused), procs name:cpu, blockers
LOG="$HOME/.drain-watch.log"
INT="${1:-300}"
case "$INT" in ""|*[!0-9]*) echo "interval must be a whole number of seconds (10-86400)"; exit 2;; esac
[ "${#INT}" -le 6 ] || { echo "interval must be 10-86400 seconds"; exit 2; }
INT=$((10#$INT))
if [ "$INT" -lt 10 ] || [ "$INT" -gt 86400 ]; then echo "interval must be 10-86400 seconds"; exit 2; fi
echo "Logging to $LOG every ${INT}s. Ctrl-C to stop."
while true; do
  ep=$(date +%s); ts=$(date "+%Y-%m-%d %H:%M:%S %z")
  batt=$(pmset -g batt)
  src=$(echo "$batt" | head -1 | grep -o "'.*'" | tr -d "'")
  ch=$(echo "$batt" | grep -o '[0-9]*%' | head -1)
  procs=$(ps -Aceo pcpu=,comm= -r | head -3 | awk '{c=$1; $1=""; sub(/^ /,""); gsub(/[,:\t]/,";"); printf "%s%s:%s", (n++?",":""), $0, c}')
  blk=$(pmset -g assertions | grep -E 'pid [0-9]+' | grep -E 'PreventUserIdleSystemSleep|PreventSystemSleep|NoIdleSleepAssertion' | grep -v '(powerd)' | sed -n 's/.*pid [0-9]*(\([^)]*\)).*/\1/p' | sort -u | paste -sd, -)
  printf '%s\t%s\t%s %s\t\t%s\t%s\n' "$ep" "$ts" "$src" "$ch" "$procs" "$blk" >> "$LOG" || { echo "cannot write $LOG"; exit 1; }
  # keep the log bounded
  if [ "$(wc -l < "$LOG")" -gt 20000 ]; then tail -n 10000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; fi
  sleep "$INT" || exit 1
done
