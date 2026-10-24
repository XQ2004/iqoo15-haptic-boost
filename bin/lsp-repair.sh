#!/system/bin/sh
# 开机自愈：只有「确认模块已登记且启用 + 作用域有 system」时才允许软重载。
# 未登记 / 被用户关闭 / sqlite3 缺失 / 登记失败时只记录并退出，绝不重启 zygote。
# 仅「刚登记 / 刚更新 APK」自动跑 1 轮；普通开机 Hook 缺失只记日志，需要时在面板点「重载 Hook」手动执行。
MODDIR=${MODDIR:-/data/adb/modules/haptic_boost_v2505a}
STATE="$MODDIR/state"
LOG=$STATE/lsp-repair.log
DB=/data/adb/lspd/config/modules_config.db
PKG=com.coldbrew.hapticboost
mkdir -p "$STATE" 2>/dev/null

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }

i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 180 ]; do sleep 2; i=$((i+1)); done
sleep 20

if [ -f "$STATE/lsp_disabled" ]; then
  log "skip: module disabled by user in LSPosed"
  exit 0
fi
if [ -f "$STATE/lsp_setup_failed" ]; then
  log "skip: lsp-setup failed: $(cat "$STATE/lsp_setup_failed" 2>/dev/null)"
  exit 0
fi

SQLITE=""
for c in "$(command -v sqlite3 2>/dev/null)" /system/bin/sqlite3 /system/xbin/sqlite3 /data/adb/ksu/bin/sqlite3 /data/adb/magisk/sqlite3; do
  [ -n "$c" ] && [ -x "$c" ] && { SQLITE="$c"; break; }
done
REG=0
if [ -f "$STATE/lsp_registered" ]; then REG=1; fi
if [ -n "$SQLITE" ] && [ -f "$DB" ]; then
  EN=$("$SQLITE" "$DB" "select enabled from modules_state where module_pkg_name='$PKG' and user_id=0;" 2>/dev/null)
  SC=$("$SQLITE" "$DB" "select count(*) from scope where module_pkg_name='$PKG' and app_pkg_name='system' and user_id=0;" 2>/dev/null)
  if [ "$EN" = "1" ] && [ "$SC" = "1" ]; then REG=1; else REG=0; fi
fi
if [ "$REG" != "1" ]; then
  log "skip: module not registered/enabled (no auto reboot)"
  exit 0
fi

# 模块内部 APK 或 LSPosed 登记有更新时, 软重载一次（最多 1 轮）
if [ -f "$STATE/lsp_changed" ]; then
  rm -f "$STATE/lsp_changed"
  log "boot: lsp config changed, soft reload (max 1 round)"
  MAX_ROUNDS=1
  export MAX_ROUNDS
  exec "$(dirname "$0")/reload-lsp.sh"
fi

if logcat -d -s LSPosedFramework:* 2>/dev/null | grep -q "HapticBoost: hook installed"; then
  log "boot: hooks present"
  exit 0
fi
# 普通开机不再自动重启 zygote：Hook 没注入时只记录，交给面板手动「重载 Hook」。
# 只有刚登记/刚更新 APK（lsp_changed）才在上面自动跑 1 轮，避免每次开机都软重启。
log "boot: hooks missing, skip auto reload (use panel manual reload)"
exit 0
