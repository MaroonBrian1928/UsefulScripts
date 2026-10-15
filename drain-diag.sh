#!/usr/bin/env bash
# drain-diag.sh — work out (in plain English) why a MacBook loses battery overnight.
#
# Usage:  ./drain-diag.sh [hours_to_look_back]      default: 18, max 720
#         sudo ./drain-diag.sh 24                    sudo gives fuller logs
#
# Run it in the morning after a bad night. It does not change any power settings
# (it only writes short-lived temp files). Thresholds below are rough heuristics,
# not Apple specifications.

HOURS="${1:-18}"
case "$HOURS" in ""|*[!0-9]*) echo "usage: $0 [hours_to_look_back (1-720)]"; exit 2;; esac
[ "${#HOURS}" -le 4 ] || { echo "hours must be 1-720"; exit 2; }
HOURS=$((10#$HOURS))
if [ "$HOURS" -lt 1 ] || [ "$HOURS" -gt 720 ]; then echo "hours must be 1-720"; exit 2; fi
CUT=$(date -v-"${HOURS}"H "+%Y-%m-%d %H:%M:%S")          # local string, for coarse text filters
CUT_E=$(date -v-"${HOURS}"H +%s)                          # epoch, for real maths
NOW_E=$(date +%s)
if [ -z "$CUT" ] || [ -z "$CUT_E" ]; then echo "could not compute time window"; exit 2; fi

PML=$(mktemp -t drainlog); RUNS=$(mktemp -t drainruns)
trap 'rm -f "$PML" "$RUNS" "$RUNS.w"' EXIT

findings=()
add() { findings+=("$1|$2"); }          # add HIGH|MED|LOW "message"
hdr() { printf '\n== %s ==\n' "$1"; }

BOOT=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/.*{ sec = \([0-9]*\).*/\1/p')
BOOT="${BOOT:-0}"

MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name|Chip/{printf "%s ", $2}')
echo "Machine: ${MODEL:-unknown}"
echo "Looking back $HOURS hours (since $CUT)"
pmset -g log > "$PML" 2>/dev/null
PM_RC=$?
[ "$(id -u)" -ne 0 ] && echo "(tip: run with sudo for fuller logs; continuing without)"

# ---------------------------------------------------------------- 1. battery
hdr "1. Battery health"
SP=$(system_profiler SPPowerDataType 2>/dev/null)
CYC=$(echo "$SP" | awk -F': ' '/Cycle Count/{print $2+0; exit}')
CAP=$(echo "$SP" | awk -F': ' '/Maximum Capacity/{gsub(/%/,"",$2); print $2+0; exit}')
COND=$(echo "$SP" | awk -F': ' '/Condition/{print $2; exit}')
echo "Cycle count: ${CYC:-?}   Max capacity: ${CAP:-?}%   Condition: ${COND:-?}"
pmset -g batt | sed 's/^/  /'
if [ -n "$CAP" ] && [ "$CAP" -gt 0 ] && [ "$CAP" -lt 80 ]; then
  add MED "Battery capacity is ${CAP}% of original. Apple designs batteries to keep up to 80% at their rated cycle count, so this is in the range where runtime is noticeably shorter. Check Settings > Battery for a 'Service Recommended' notice."
fi
[ -n "$CYC" ] && [ "$CYC" -gt 1000 ] && add LOW "The battery has ${CYC} charge cycles. Compare with Apple's rated cycle count for your model (support.apple.com/102888)."
case "$COND" in ""|Normal) ;; *) add HIGH "macOS reports the battery condition as '$COND', not 'Normal'. The battery itself may be faulty.";; esac

# ---------------------------------------------------------------- 2. settings
hdr "2. Power settings while on battery"
BATT_SET=$(pmset -g custom 2>/dev/null | awk '/^Battery Power:/{f=1;next} /^AC Power:/{f=0} f')
bset() { echo "$BATT_SET" | awk -v k="$1" '$1==k{print $2; exit}'; }
for k in sleep displaysleep powernap tcpkeepalive womp standby hibernatemode lowpowermode networkoversleep proximitywake; do
  printf '  %-16s %s\n' "$k" "$(bset $k)"
done
SD=$(pmset -g 2>/dev/null | awk '$1=="SleepDisabled"{print $2; exit}')
echo "  SleepDisabled    ${SD:-?}"
[ "$SD" = "1" ] && add HIGH "Sleep is globally DISABLED (pmset disablesleep=1): the Mac will not sleep even with the lid closed. (Fix: sudo pmset -a disablesleep 0)"
[ "$(bset sleep)" = "0" ]    && add MED "The idle-sleep timer is 'never' on battery: a Mac left open and idle will not sleep by itself (closing the lid still sleeps it). (Fix: sudo pmset -b sleep 1)"
[ "$(bset powernap)" = "1" ] && add LOW "Power Nap is set on for battery. It lets the Mac wake periodically to fetch mail/iCloud data. macOS may ignore this setting on some models, so check the wake counts in sections 3-4 before blaming it. (Change: sudo pmset -b powernap 0)"
[ "$(bset womp)" = "1" ]     && add LOW "'Wake for network access' is on for battery, which allows network 'magic packet' wakes. (Change: sudo pmset -b womp 0)"
[ "$(bset standby)" = "0" ]  && add LOW "Standby is off (pmset standby 0), so long sleeps do not drop into deep hibernation and keep drawing a little power."
SCHED=$(pmset -g sched 2>/dev/null | sed '/^Scheduled power events:/d;/^$/d')
if [ -n "$SCHED" ]; then
  echo "  Scheduled power events:"; echo "$SCHED" | sed 's/^/    /'
  OTHER=$(echo "$SCHED" | grep -v 'com.apple.alarm')
  [ -n "$OTHER" ] && add LOW "There are scheduled wake/power events that are not standard macOS timers: $(echo "$OTHER" | tr '\n' ';' | tr -s ' ')"
fi

# ---------------------------------------------------------------- 3. sleep history
hdr "3. What happened overnight (sleep/wake log)"
EVENTS=$(awk '$1 ~ /^20[0-9][0-9]-/ && ($4=="Sleep"||$4=="Wake"||$4=="DarkWake") && $5!="Requests"' "$PML" | wc -l | tr -d ' ')
ONBATT=$(awk -v cut="$CUT" '($1" "$2)>=cut' "$PML" | grep -ci 'using batt')
if [ "$PM_RC" -ne 0 ] || [ "$EVENTS" -eq 0 ]; then
  echo "  Could not read any sleep/wake events from 'pmset -g log' (try sudo). Nothing below can be trusted."
  add MED "The power log could not be read, so sleep, wake and drain results are unavailable. Try: sudo ~/drain-diag.sh"
fi

awk -v cut="$CUT_E" -v boot="$BOOT" -v nowe="$NOW_E" '
function dn(y,m,d,  a,yy,mm){a=int((14-m)/12);yy=y+4800-a;mm=m+12*a-3;return d+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045}
function ts(D,T,Z,  a,b,sg,off){split(D,a,"-");split(T,b,":")
  sg=(substr(Z,1,1)=="-")?-1:1; off=sg*(substr(Z,2,2)*3600+substr(Z,4,2)*60)
  return (dn(a[1]+0,a[2]+0,a[3]+0)-2440588)*86400+b[1]*3600+b[2]*60+b[3]-off}
$1 !~ /^20[0-9][0-9]-/ {next}
{
  ev=$4
  if (ev=="Start") { disc=1; next }               # logged restart: break pairing here
  if (ev!="Sleep" && ev!="Wake" && ev!="DarkWake") next
  if ($5=="Requests") next
  if (ev=="Sleep" && $0 ~ /Entering DarkWake/) next
  t=ts($1,$2,$3)
  ch=-1; if (match($0,/Charge:[0-9]+/)) ch=substr($0,RSTART+7,RLENGTH-7)+0
  batt=(tolower($0) ~ /using batt/)?1:0
  r=$0; if (sub(/.*due to /,"",r)) { sub(/ Using .*/,"",r); sub(/:.*/,"",r) } else r="?"
  k=(ev=="Sleep")?"S":((ev=="DarkWake")?"D":"W")
  if (t>=cut) { evw++; if (batt) eb++; else ea++; if (ch<0) eu++ }
  if (have) {
    d=t-pt; span=((boot>pt && boot<t) || disc || d<0); disc=0
    if (open) { if (span) rspan=1; if (!(pb && batt)) rmix=1 }
    if (t>cut && pt>=cut && !span) {
      key=(pk=="S")?"S":"A"
      if (pb && batt && pch>=0 && ch>=0) {
        dr=pch-ch; if (dr<0) dr=0
        secs[key]+=d; drp[key]+=dr
        if (open) { rbs+=d; rbd+=dr }
      } else { nb[key]+=d }
    }
  }
  if (k=="S") {
    if (!open) { open=1; st=t; sts=$1" "substr($2,1,5); sch=ch; sb=batt; dw=0; rbs=0; rbd=0; rspan=0; rmix=0; why=r }
  } else if (k=="D") {
    if (open && batt) dw++
    if (t>=cut) print "D|" t "|" r
  } else {
    if (open) {
      if (t>cut) {
        fl=""; if (st<cut) fl=fl "C"; if (rspan) fl=fl "R"; if (rmix) fl=fl "M"
        printf "RUN|%s|%s %s|%.2f|%.2f|%d|%d|%s|%s\n", sts, $1, substr($2,1,5), (t-st)/3600, rbs/3600, rbd, dw, fl, why
      }
      open=0
    }
  }
  pt=t; pch=ch; pb=batt; pk=k; have=1
}
END {
  printf "COV|%d|%d|%d|%d\n", evw, eb, ea, eu
  if (open) printf "OPEN|%s|%d|%d|%d\n", sts, sch, sb, st
  printf "TOT|%.2f|%d|%.2f|%d\n", secs["S"]/3600, drp["S"], secs["A"]/3600, drp["A"]
}' "$PML" > "$RUNS"

TOT=$(grep '^TOT|' "$RUNS" | head -1)
IFS='|' read -r _ S_H S_D A_H A_D <<< "$TOT"
IFS='|' read -r _ EVW EB EA EU <<< "$(grep '^COV|' "$RUNS" | head -1)"
EVW="${EVW:-0}"; EB="${EB:-0}"; EA="${EA:-0}"; EU="${EU:-0}"
S_H="${S_H:-0}"; S_D="${S_D:-0}"; A_H="${A_H:-0}"; A_D="${A_D:-0}"
printf '  On battery in the window: asleep %sh (lost %s%%), awake or dark-waking %sh (lost %s%%).\n' "$S_H" "$S_D" "$A_H" "$A_D"
echo "  (Only time between log entries that were both on battery is counted; charger time is excluded.)"

num_ge() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0>=b+0)}'; }
LONG=0
while IFS='|' read -r tag s e h bh bd dw fl why; do
  [ "$tag" = "RUN" ] || continue
  num_ge "$h" 2 || continue
  LONG=$((LONG+1))
  note=""
  case "$fl" in *C*) note="$note started before the window;";; esac
  case "$fl" in *R*) note="$note spans a reboot;";; esac
  case "$fl" in *M*) note="$note part of it was on the charger;";; esac
  note="${note# }"; note="${note%;}"
  base="  Slept $s -> woke $e (${h}h, $dw battery dark-wakes)"
  case "$fl" in
    *R*) echo "$base: not measured — $note"; continue;;
  esac
  if num_ge "$bh" 1.5; then
    rate=$(awk -v d="$bd" -v h="$bh" 'BEGIN{printf "%.2f", d/h}')
    echo "$base: on battery ${bh}h, lost ${bd}% = ${rate}%/hour${note:+ ($note)} [sleep period incl. brief dark wakes]"
    if [ "$bd" -ge 3 ] && num_ge "$rate" 2; then
      add HIGH "Night of $s: lost ${bd}% over ${bh}h of battery-powered sleep (${rate}%/hour, incl. brief dark wakes). That is high for sleep (rough guide: well under 1%/hour). Something is waking or keeping the Mac busy — see sections 4, 5 and 9."
    elif [ "$bd" -ge 3 ] && num_ge "$rate" 1; then
      add MED "Night of $s: lost ${bd}% over ${bh}h of battery-powered sleep (${rate}%/hour, incl. brief dark wakes), on the high side for sleep (rough guide: under ~1%/hour)."
    fi
    DWPH=$(awk -v d="$dw" -v h="$bh" 'BEGIN{printf "%.1f", d/h}')
    num_ge "$DWPH" 8 && add LOW "Night of $s: $dw dark-wakes on battery over ${bh}h (~$DWPH per hour). Each one uses some power; section 4 shows what triggered them."
  else
    echo "$base: only ${bh}h of it measurable on battery — ${note:-on the charger, or charge level not logged}"
  fi
done < "$RUNS"

OPEN=$(grep '^OPEN|' "$RUNS" | head -1)
if [ -n "$OPEN" ]; then
  IFS='|' read -r _ s c1 b st_e <<< "$OPEN"
  echo "  The log's last sleep began $s at ${c1}% ($( [ "$b" = 1 ] && echo battery || echo charger )) with no later wake recorded."
  if [ "$b" = "1" ] && [ "$BOOT" -gt "$st_e" ]; then
    add MED "The Mac went to sleep on battery at $s (${c1}%), the Mac rebooted later, and no wake was logged in between. That is consistent with the battery running out, but it is not proof — check section 7."
  else
    add LOW "The log ends with a sleep at $s and no matching wake (the log may be truncated, or you ran this during a dark wake). Treat sleep results as incomplete."
  fi
fi

if [ "$EVENTS" -gt 0 ]; then
  if [ "$EVW" -eq 0 ]; then
    echo "  No sleep/wake entries fall inside the window. Either the Mac never changed power state (awake the whole time — see section 5) or the log does not reach back this far; this script cannot tell which."
    add LOW "The power log has no sleep/wake entries inside the last $HOURS hours, so nothing about sleep drain could be measured."
  elif [ "$EB" -eq 0 ] && [ "$EA" -gt 0 ]; then
    echo "  Every power-state entry in the window was on the charger — so there is no battery drain to explain."
  elif [ "$LONG" -eq 0 ] && [ -z "$OPEN" ]; then
    echo "  No sleep stretch of 2+ hours found in the window."
    if num_ge "$A_H" 4 && ! num_ge "$S_H" 1; then
      add MED "On battery the Mac was awake ~${A_H}h (lost ${A_D}%) and asleep only ~${S_H}h. If that includes a night, it was left running — check sleep blockers (section 5), the overnight watcher (section 9) and whether the lid was open."
    fi
  fi
  [ "$EU" -gt 0 ] && echo "  ($EU log entries had no charge level, so some intervals could not be measured.)"
fi

# ---------------------------------------------------------------- 4. wake reasons
hdr "4. Who/what kept waking it up"
explain() {
  case "$1" in
    *[Ll][Ii][Dd]*)     echo "lid opened/closed";;
    *RTC*|*rtc*|*Alarm*) echo "a scheduled timer";;
    *Maintenance*)      echo "macOS maintenance wake";;
    *ACAttach*|*ACDetach*) echo "charger plugged in/unplugged";;
    *ARPT*|*WiFi*|*WLAN*|*Network*) echo "network traffic over Wi-Fi";;
    *USB*|*XHC*|*OHC*|*EHC*|*HID*) echo "a USB/keyboard-type device";;
    *GLAN*)             echo "wired network (Ethernet/dock)";;
    *BT*|*[Bb]luetooth*) echo "a Bluetooth device";;
    *SMC*|*AOP*)        echo "hardware controller event";;
    *) echo "";;
  esac
}
if grep -q '^D|' "$RUNS"; then
  echo "  Dark-wake triggers in the window (count, reason):"
  grep '^D|' "$RUNS" | cut -d'|' -f3- | sort | uniq -c | sort -rn | head -6 | while read -r n r; do
    printf '    %4s  %s   %s\n' "$n" "$r" "$(explain "$r")"
  done
else
  echo "  No dark wakes recorded in the window."
fi
echo "  Apps/daemons that scheduled a wake-up (distinct requests, not repeats):"
WREQ=$(awk -v cut="$CUT" '($1" "$2)>=cut' "$PML" | grep 'Wake Requests' | grep -oE 'process=[^] ,]+ [^]]*wakeAt=[0-9-]+ [0-9:]+' \
  | sed -E 's/process=([^ ]+) .*wakeAt=(.*)/\1|\2/' | sort -u | cut -d'|' -f1 | sort | uniq -c | sort -rn | head -8)
[ -n "$WREQ" ] && echo "$WREQ" | sed 's/^/    /' || echo "    (none logged)"
if [ -n "$WREQ" ]; then
  TOPW=$(echo "$WREQ" | head -1 | awk '{print $2}')
  case "$TOPW" in powerd|dasd|mDNSResponder|kernel_task|apsd|bluetoothd|sharingd|cloudd|bird|locationd|symptomsd|rapportd|identityservicesd|searchpartyd|configd|networkd|"") ;;
    *) add LOW "The process that scheduled the most distinct wake-ups was '$TOPW'. If it is a third-party app, check its sync/backup/update settings.";;
  esac
fi

# ---------------------------------------------------------------- 5. blockers now
hdr "5. Things currently preventing system sleep"
BLK=$(pmset -g assertions 2>/dev/null | grep -E 'pid [0-9]+' | grep -E 'PreventUserIdleSystemSleep|PreventSystemSleep|NoIdleSleepAssertion' | grep -v '(powerd)')
if [ -n "$BLK" ]; then
  echo "$BLK" | sed 's/^ */  /'
  echo "  (System services such as sharingd/coreaudiod appear briefly during normal use; caffeinate, video calls, Docker/VMs, downloads and playback are the usual long-running culprits.)"
  NAMES=$(echo "$BLK" | sed -n 's/.*pid [0-9]*(\([^)]*\)).*/\1/p' | sort -u | grep -vxE 'sharingd|coreaudiod|cloudd|bird|apsd|backupd|UserEventAgent' | tr '\n' ' ')
  [ -n "$NAMES" ] && add MED "Right now these programs are telling macOS not to sleep: $NAMES. This is a snapshot, not a record of last night; run again just before bed, or use the overnight watcher (section 9)."
else
  echo "  Nothing is holding the Mac awake at this moment."
fi

# ---------------------------------------------------------------- 6. busy processes
hdr "6. Busiest processes right now (CPU)"
TOPOUT=$(top -l 2 -s 2 -n 8 -o cpu -stats pid,command,cpu 2>/dev/null | awk '/^PID/{n++; next} n==2')
if [ -z "$TOPOUT" ]; then
  echo "  (could not sample top)"
else
  echo "$TOPOUT" | awk '{c=$NF; $1=""; $NF=""; printf "  %5.1f%%  %s\n", c, $0}'
fi
while IFS='|' read -r nm cpu; do
  [ -n "$cpu" ] || continue
  nm=$(echo "$nm" | sed 's/^ *//;s/ *$//')
  case "$nm" in
    mds*|mdworker*|spotlight*|corespotlight*) why="Spotlight is indexing (normal after updates/big file changes)";;
    photoanalysisd|photolibraryd) why="Photos is analysing your library";;
    backupd|*TimeMachine*) why="Time Machine backup";;
    bird|cloudd|fileproviderd) why="iCloud Drive syncing";;
    kernel_task)     why="system-level work or thermal management";;
    *Chrome*|*Safari*|*Firefox*|*WebKit*) why="a browser tab using CPU (video, ad, or runaway page)";;
    *docker*|*Docker*|*qemu*|*Parallels*|*prl_*|*VMware*) why="a VM/container is running";;
    searchpartyd*)   why="Find My network location work (usually brief)";;
    *) why="";;
  esac
  add LOW "'$nm' was using ~${cpu}% CPU at the moment of this run${why:+ — $why}. That is a snapshot; it says nothing about last night unless the watcher (section 9) saw it too."
done <<EOF2
$(echo "$TOPOUT" | awk '$NF+0>=40{ $1=""; n=$NF; $NF=""; print $0 "|" n }')
EOF2

# ---------------------------------------------------------------- 7. crashes
hdr "7. Restarts, shutdowns and crashes"
if [ "$BOOT" -gt 0 ]; then
  UPH=$(( (NOW_E - BOOT) / 3600 ))
  echo "  Booted $(date -r "$BOOT" '+%Y-%m-%d %H:%M') (~${UPH}h ago)"
  [ "$BOOT" -ge "$CUT_E" ] && add LOW "The Mac booted ~${UPH}h ago, inside the window. That could be a deliberate restart, an update, a crash, or the battery running out — check the shutdown-cause line below and section 3."
fi
CAUSES=$(log show --last "${HOURS}h" --predicate 'eventMessage contains "Previous shutdown cause"' 2>/dev/null | grep -o 'shutdown cause: *-\?[0-9]*' | sed 's/.*: *//' | tail -3)
if [ -n "$CAUSES" ]; then
  for c in $CAUSES; do
    case "$c" in
      5) m="clean shutdown/restart";;
      3) m="forced/'dirty' shutdown (power button held or hang)"; add MED "A shutdown cause of 3 (forced/dirty shutdown) was logged in the window.";;
      0) m="cause 0: not clearly documented; seen after sudden power loss, among other things"; add MED "A shutdown cause of 0 was logged in the window. That is not clearly documented, but it can follow sudden power loss such as a battery running out.";;
      *) m="other code (not interpreted)";;
    esac
    echo "  Previous shutdown cause: $c — $m"
  done
else
  echo "  No shutdown-cause message found in the window (Apple silicon Macs often log none, or the log was not readable without sudo)."
fi
PAN=$(find /Library/Logs/DiagnosticReports ~/Library/Logs/DiagnosticReports -maxdepth 1 \( -iname '*panic*' -o -name 'Kernel*' \) -mmin -$((HOURS*60)) 2>/dev/null)
if [ -n "$PAN" ]; then echo "  Panic/kernel reports in the window:"; echo "$PAN" | sed 's/^/    /'; add HIGH "Kernel panic reports were written in the window (listed above). A crash overnight can look like 'died in the night'."; fi

# ---------------------------------------------------------------- 8. login items
hdr "8. Non-Apple background jobs loaded (first 15)"
launchctl list 2>/dev/null | awk 'NR>1 && $3 !~ /^com\.apple\./ && $3 !~ /^application\./ && $3 !~ /^0x/ {print "  " $3}' | head -15

# ---------------------------------------------------------------- 9. overnight watcher
hdr "9. Overnight watcher log (from drain-watch.sh)"
WL="$HOME/.drain-watch.log"
if [ -s "$WL" ]; then
  awk -F'\t' -v cut="$CUT_E" '$1>=cut' "$WL" > "$RUNS.w"
  N=$(wc -l < "$RUNS.w" | tr -d ' ')
  if [ "$N" -eq 0 ]; then
    echo "  The watcher log has no samples in this window."
  else
    NB=$(awk -F'\t' '$3 ~ /Batt/' "$RUNS.w" | wc -l | tr -d ' ')
    echo "  $N samples ($NB on battery), from $(awk -F'\t' 'NR==1{print $2}' "$RUNS.w") to $(awk -F'\t' 'END{print $2}' "$RUNS.w")."
    echo "  (Samples only happen while the Mac is awake, so gaps are normal sleep.)"
    echo "  Processes seen using 10%+ CPU while sampled (samples, name):"
    awk -F'\t' '{n=split($5,a,","); for(i=1;i<=n;i++){split(a[i],b,":"); if (b[2]+0>=10) print b[1]}}' "$RUNS.w" | sort | uniq -c | sort -rn | head -5 | sed 's/^/    /'
    echo "  Sleep blockers seen (samples, name):"
    awk -F'\t' '$6!=""{n=split($6,a,","); for(i=1;i<=n;i++) print a[i]}' "$RUNS.w" | sort | uniq -c | sort -rn | head -5 | sed 's/^/    /'
    BL=$(awk -F'\t' '$3 ~ /Batt/ && $6!=""{n=split($6,a,","); for(i=1;i<=n;i++) print a[i]}' "$RUNS.w" | sort | uniq -c | sort -rn | awk '$1>=2{print $2}' | grep -vxE 'sharingd|coreaudiod|cloudd|bird|apsd|backupd|UserEventAgent' | head -3 | tr '\n' ' ')
    [ -n "$BL" ] && add MED "The watcher saw these sleep blockers on at least two separate battery-powered samples: $BL. See section 9."
  fi
  rm -f "$RUNS.w"
else
  echo "  No watcher log. Run ./drain-watch.sh before bed to record overnight activity."
fi

# ---------------------------------------------------------------- verdict
hdr "VERDICT (plain English)"
if [ "${#findings[@]}" -eq 0 ]; then
  echo "  Nothing obviously wrong turned up. If it still dies overnight:"
  echo "   - Run this again right before bed (to catch sleep blockers) and again in the morning."
  echo "   - Start ./drain-watch.sh before bed; note whether the lid is closed and whether it is in a warm bag."
  echo "   - Run Apple Diagnostics: shut down, press and hold the power button until startup options appear, then press and hold Command-D."
else
  for sev in HIGH MED LOW; do
    for f in "${findings[@]}"; do
      [ "${f%%|*}" = "$sev" ] && printf '  [%s] %s\n\n' "$sev" "${f#*|}"
    done
  done
fi
exit 0
