#!/system/bin/sh
# KSU 卸载入口：先做完整残留清理（含面板卸载/LSPosed 撤登记/参数表 umount），再删模块目录。
MODDIR=${MODDIR:-${0%/*}}
case "$MODDIR" in /data/adb/modules/*) ;; *) MODDIR=/data/adb/modules/haptic_boost_v2505a ;; esac
if [ -f "$MODDIR/bin/cleanup.sh" ]; then
    sh "$MODDIR/bin/cleanup.sh" --uninstall
fi
rm -rf "$MODDIR" 2>/dev/null
rm -rf /data/adb/modules_update/haptic_boost_v2505a 2>/dev/null
echo "haptic_boost: uninstalled"
exit 0
