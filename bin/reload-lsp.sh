#!/system/bin/sh
# reload LSPosed daemon and soft-restart zygote until the haptic hook is live.
# Probe = prebaked rewrite check (feedback CLICK -> HEAVY_CLICK), no reboot needed.
MODDIR=${MODDIR:-/data/adb/modules/haptic_boost_v2505a}
STATE="$MODDIR/state"
LOG=$STATE/lsp-repair.log
mkdir -p "$STATE"
[ -d "$STATE/.lsp-lock" ] && { echo "already running"; exit 0; }
mkdir "$STATE/.lsp-lock" 2>/dev/null || { echo "already running"; exit 0; }
trap 'rmdir "$STATE/.lsp-lock" 2>/dev/null' EXIT INT TERM

log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }

probe() {
  P="prb$(date +%s)$$"
  cmd vibrator_manager feedback -d "$P" 3 >/dev/null 2>&1
  sleep 1
  LINE=$(dumpsys vibrator_manager | grep "constant=3): $P" | tail -1)
  echo "$LINE" | grep -q "HEAVY_CLICK" && return 0
  return 1
}

hooked_log() {
  logcat -d -s LSPosedFramework:* 2>/dev/null | grep -c "HapticBoost: hook installed"
}

MAX_ROUNDS=${MAX_ROUNDS:-4}
case "$MAX_ROUNDS" in ''|*[!0-9]*) MAX_ROUNDS=4 ;; esac
[ "$MAX_ROUNDS" -ge 1 ] 2>/dev/null || MAX_ROUNDS=4
log "=== reload start (max ${MAX_ROUNDS} rounds) ==="
i=0
while [ $i -lt "$MAX_ROUNDS" ]; do
  i=$((i+1))
  log "round $i: log-marker=$(hooked_log)"
  if probe; then log "round $i: probe OK (prebaked rewritten)"; break; fi
  log "round $i: restarting lspd + zygote"
  kill -9 $(pidof lspd) 2>/dev/null
  sleep 2
  if [ -x /data/adb/modules/zygisk_lsposed/daemon ]; then
    nohup /data/adb/modules/zygisk_lsposed/daemon --force >/dev/null 2>&1 &
  fi
  sleep 15
  setprop ctl.restart zygote
  sleep 35
done

if probe; then
  log "RESULT hooked"
  echo "hooked"
else
  log "RESULT not-hooked"
  echo "not-hooked"
fi
log "=== reload end ==="
