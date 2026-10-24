#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/bin/common.sh"
if [ "$TARGET_FOUND" = "1" ]; then
  i=0
  while [ ! -f "$TARGET" ] && [ $i -lt 20 ]; do sleep 0.5; i=$((i+1)); done
fi
"$MODDIR/bin/apply.sh" "$(cur_level)" >> "$STATE/boot.log" 2>&1
# KernelSU: lspd runs in ksu domain; its data dir must not be system_file
[ -d /data/adb/lspd ] && chcon -R u:object_r:ksu_file:s0 /data/adb/lspd 2>/dev/null
# early LSPosed daemon so the zygote fork sees module config
if [ -x /data/adb/modules/zygisk_lsposed/daemon ] && ! pidof lspd >/dev/null 2>&1; then
  /data/adb/modules/zygisk_lsposed/daemon >/dev/null 2>&1 &
fi
