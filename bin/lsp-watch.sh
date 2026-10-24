#!/system/bin/sh
# LSPosed 运行时看守：
#  1) modules 行还在但 apk_path 为空 -> 修复（包更新/重装后 LSPosed 会清空它并自动关模块）
#  2) enabled=0 且 lock=1 -> 视为 LSPosed 自动关闭，直接拉回启用，不重启 zygote
#  3) 只有用户 settings put global haptic_boost_lock_lsp 0 后才尊重手动关闭
MODDIR=${0%/*}; MODDIR=${MODDIR%/bin}
. "$MODDIR/bin/common.sh"
PKG=com.coldbrew.hapticboost
DB=/data/adb/lspd/config/modules_config.db
LOG=$STATE/lsp-watch.log
LOCKDIR=$STATE/.lsp-watch
mkdir -p "$STATE" 2>/dev/null

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }

[ -f "$DB" ] || exit 0

USER_LOCK=$(settings get global haptic_boost_lock_lsp 2>/dev/null | tr -d '\r')
[ "$USER_LOCK" = "0" ] || USER_LOCK=1
# lock=1 时旧的 lsp_disabled 标记作废，否则看守永远不会再启动
if [ "$USER_LOCK" = "1" ]; then
  rm -f "$STATE/lsp_disabled"
elif [ -f "$STATE/lsp_disabled" ]; then
  exit 0
fi

SQLITE=""
for c in "$(command -v sqlite3 2>/dev/null)" /system/bin/sqlite3 /system/xbin/sqlite3 /data/adb/ksu/bin/sqlite3 /data/adb/magisk/sqlite3; do
  [ -n "$c" ] && [ -x "$c" ] && { SQLITE="$c"; break; }
done
[ -n "$SQLITE" ] || exit 0

[ -d "$LOCKDIR" ] && exit 0
mkdir "$LOCKDIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT INT TERM

q() { "$SQLITE" "$DB" "$1" 2>/dev/null; }

# 自动关闭发生时留一份现场：DB 行、lspd 进程、LSPosed logcat 尾部。
snapshot() {
  SNAP="$STATE/lsp-disable-$(date '+%m%d-%H%M%S').log"
  {
    echo "== $(date '+%Y-%m-%d %H:%M:%S') reason=$* =="
    echo "lock=$USER_LOCK pidof_lspd=$(pidof lspd 2>/dev/null)"
    echo "-- modules --"; q "select module_pkg_name,apk_path from modules where module_pkg_name='$PKG';"
    echo "-- state --"; q "select module_pkg_name,user_id,enabled from modules_state where module_pkg_name='$PKG';"
    echo "-- scope --"; q "select module_pkg_name,app_pkg_name,user_id from scope where module_pkg_name='$PKG';"
    echo "-- ps --"; ps -A -o PID,PPID,NAME 2>/dev/null | grep -E 'lspd|zygisk' | head -10
    echo "-- logcat --"; logcat -d -v time -s LSPosedFramework:* LSPosed:* AndroidRuntime:E 2>/dev/null | tail -n 300
  } > "$SNAP" 2>&1
  ls -t "$STATE"/lsp-disable-*.log 2>/dev/null | tail -n +4 | while read -r f; do rm -f "$f"; done
}

log "watch start lock=$USER_LOCK"
TICK=0

while true; do
  sleep 30
  TICK=$((TICK+1))
  USER_LOCK=$(settings get global haptic_boost_lock_lsp 2>/dev/null | tr -d '\r')
  [ "$USER_LOCK" = "0" ] || USER_LOCK=1

  if [ "$USER_LOCK" = "0" ]; then
    log "lock=0 -> stop watchdog"
    echo 1 > "$STATE/lsp_disabled"
    exit 0
  fi

  if ! pidof lspd >/dev/null 2>&1; then
    log "lspd not running -> restart daemon (no zygote restart)"
    [ -x /data/adb/modules/zygisk_lsposed/daemon ] && nohup /data/adb/modules/zygisk_lsposed/daemon --force >/dev/null 2>&1 &
    sleep 5
  fi

  ROWS=$(q "select count(*) from modules where module_pkg_name='$PKG';")
  CUR=$(q "select apk_path from modules where module_pkg_name='$PKG';")
  EN=$(q "select enabled from modules_state where module_pkg_name='$PKG' and user_id=0;")

  if [ "$ROWS" = "0" ]; then
    log "modules row missing -> register"
    FORCE_ENABLE=1 sh "$MODDIR/bin/lsp-setup.sh" >> "$LOG" 2>&1
    rm -f "$STATE/lsp_changed"
    continue
  fi
  if [ "$ROWS" != "1" ]; then
    log "modules query failed (rows=$ROWS) -> skip"
    continue
  fi
  if [ $((TICK % 10)) -eq 0 ]; then
    log "alive tick=$TICK enabled=$EN path=${CUR:+set}"
  fi

  if [ "$EN" = "0" ]; then
    snapshot "enabled=0 path=${CUR:+set}"
    log "enabled=0 (lock=1) -> force re-enable"
    FORCE_ENABLE=1 sh "$MODDIR/bin/lsp-setup.sh" >> "$LOG" 2>&1
    rm -f "$STATE/lsp_changed"
    if [ -f "$STATE/lsp_setup_failed" ]; then
      log "re-enable failed: $(cat "$STATE/lsp_setup_failed" 2>/dev/null)"
    else
      log "re-enabled"
    fi
    continue
  fi

  if [ -z "$CUR" ]; then
    snapshot "empty apk_path enabled=$EN"
    log "empty apk_path (enabled=$EN) -> repair"
    sh "$MODDIR/bin/lsp-setup.sh" >> "$LOG" 2>&1
    rm -f "$STATE/lsp_changed"
    if [ -f "$STATE/lsp_setup_failed" ]; then
      log "repair failed: $(cat "$STATE/lsp_setup_failed" 2>/dev/null)"
    else
      log "apk_path repaired"
    fi
    continue
  fi
done
