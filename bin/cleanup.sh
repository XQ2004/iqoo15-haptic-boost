#!/system/bin/sh
# 振动增强 · 残留清理
# 用法: su -c 'sh /data/local/tmp/hb_cleanup.sh'            仅清残留
#       su -c 'sh /data/local/tmp/hb_cleanup.sh --uninstall' 清残留并卸载面板
# 幂等：可重复执行，失败不阻断后续步骤。

LOG=/data/local/tmp/hb_cleanup.log
exec >>"$LOG" 2>&1
echo "===== cleanup $(date) arg=$1 ====="

# 参数表可能不在 /vendor/etc（V2301A 就没有该文件），复用 common.sh 的探测逻辑。
# cleanup 可能从 /data/local/tmp 执行，不能按 $0 推断模块目录，这里固定模块路径。
MODDIR=${MODDIR:-/data/adb/modules/haptic_boost_v2505a}
[ -f "$MODDIR/bin/common.sh" ] && . "$MODDIR/bin/common.sh"
STATE=${STATE:-$MODDIR/state}
TARGET=${TARGET:-/vendor/etc/Hapticsconfig.xml}

# 0) 停掉运行时看守，避免清理后它又把状态写回来
pkill -f lsp-watch.sh 2>/dev/null || true
ps -A -o PID,ARGS 2>/dev/null | grep '[l]sp-watch.sh' | awk '{print $1}' | while read -r p; do kill "$p" 2>/dev/null; done
rm -rf "$STATE/.lsp-watch" 2>/dev/null || true

# 1) 撤掉参数表 bind mount（最多三层，防止叠加；同时清旧默认路径）
for t in "$TARGET" /vendor/etc/Hapticsconfig.xml; do
    [ -n "$t" ] || continue
    i=0
    while [ $i -lt 3 ]; do
        umount "$t" 2>/dev/null || umount -l "$t" 2>/dev/null || break
        i=$((i + 1))
    done
done

# 2) 让 HAL 重新读取原生参数表
killall vendor.vivo.hardware.vibrator.custom.service 2>/dev/null || true
killall vendor.vivo.hardware.vibrator.custom 2>/dev/null || true

# 3) 清 LSPosed 注册行（经典 + libxposed 两套包名实验残留）
DB=/data/adb/lspd/config/modules_config.db
if [ -f "$DB" ] && command -v sqlite3 >/dev/null 2>&1; then
    for pkg in com.coldbrew.hapticboost; do
        sqlite3 "$DB" "DELETE FROM scope WHERE module_pkg_name='$pkg';" 2>/dev/null || true
        sqlite3 "$DB" "DELETE FROM modules_state WHERE module_pkg_name='$pkg';" 2>/dev/null || true
        sqlite3 "$DB" "DELETE FROM module_configs WHERE module_pkg_name='$pkg';" 2>/dev/null || true
        sqlite3 "$DB" "DELETE FROM modules WHERE module_pkg_name='$pkg';" 2>/dev/null || true
    done
    sqlite3 "$DB" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
fi

# 4) 清 settings 键（Hook 的 3 秒 TTL 会读到空值 → 回默认）
settings list global 2>/dev/null | grep '^haptic_boost_' | cut -d= -f1 | while read -r key; do
    [ -n "$key" ] && settings delete global "$key" >/dev/null 2>&1
done

# 5) 清日志与临时文件
rm -f /data/system/haptic_boost_trace.log
rm -f /data/system/haptic_boost_trace.log.old
rm -f /data/local/tmp/haptic_boost_active.xml
rm -f /data/local/tmp/hb_haptics.xml
rm -f /data/local/tmp/hb_lsp.apk
rm -f /data/local/tmp/hb_new.apk
rm -rf /data/local/tmp/hb
rm -rf /data/local/tmp/hb_src
rm -f /data/local/tmp/upd*.sh
rm -f /data/local/tmp/inst*.sh

# 6) 清状态目录与 OTA 残留
rm -rf /data/adb/haptic_boost
rm -rf /data/adb/modules_update/haptic_boost_v2505a

# 7) 可选卸载面板
if [ "$1" = "--uninstall" ]; then
    pm uninstall com.coldbrew.hapticboost >/dev/null 2>&1 || true
    pm uninstall --user 0 com.coldbrew.hapticboost >/dev/null 2>&1 || true
    # 让 system_server 丢掉已注入的 Hook，卸载后立即回到原生震感
    setprop ctl.restart zygote >/dev/null 2>&1 || true
    rm -f /data/local/tmp/hb_cleanup.log 2>/dev/null || true
fi
[ "$0" = "/data/local/tmp/hb_cleanup.sh" ] || rm -f /data/local/tmp/hb_cleanup.sh 2>/dev/null || true

echo CLEAN_OK
