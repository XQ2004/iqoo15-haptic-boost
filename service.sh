#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/bin/common.sh"
sleep 3
# 指纹解锁的 VivoEffectIDSegment 需要 com.vivo.fingerprintui 在 Hook 白名单里
ensure_vendor_pkgs
is_mounted || "$MODDIR/bin/apply.sh" "$(cur_level)" >> "$STATE/boot.log" 2>&1
# 模块内置 APK: 刷入/更新后自动装到桌面(幂等, 按文件字节数判断)
"$MODDIR/bin/install-apk.sh" >> "$STATE/boot.log" 2>&1
# 自动登记进 LSPosed: 启用 + 作用域勾「系统框架」+ WAL checkpoint
"$MODDIR/bin/lsp-setup.sh" >> "$STATE/boot.log" 2>&1
"$MODDIR/bin/status.sh" >> "$STATE/status.log" 2>&1
tail -n 50 "$STATE/status.log" > "$STATE/status.tmp" 2>/dev/null && mv "$STATE/status.tmp" "$STATE/status.log"
# self heal LSPosed hook in background: daemon restart + zygote restart (soft, no full reboot)
[ -x "$MODDIR/bin/lsp-repair.sh" ] && "$MODDIR/bin/lsp-repair.sh" >/dev/null 2>&1 &
# 运行时看守：修 LSPosed 被清空的 apk_path（否则模块会在几分钟后被自动关闭）
[ -x "$MODDIR/bin/lsp-watch.sh" ] && nohup "$MODDIR/bin/lsp-watch.sh" >/dev/null 2>&1 &
