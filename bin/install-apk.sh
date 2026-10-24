#!/system/bin/sh
# 首次开机/模块更新后, 把模块内置的 APK 装到桌面 (幂等: 按文件字节数做标记)
MODDIR=${0%/*}; MODDIR=${MODDIR%/bin}
. "$MODDIR/bin/common.sh"
PKG=com.coldbrew.hapticboost
APK="$MODDIR/apk/HapticBoostLSP.apk"
[ -f "$APK" ] || { echo "$(date '+%m-%d %H:%M:%S') install-apk: no apk in module" >> "$STATE/boot.log"; exit 0; }
SIZE=$(wc -c < "$APK" | tr -d ' ')
MD5=$(md5sum "$APK" 2>/dev/null | awk '{print $1}')
[ -n "$MD5" ] || MD5="size:$SIZE"
MARK="$STATE/apk_md5"
OLD=$(cat "$MARK" 2>/dev/null || echo "")
INSTALLED=$(pm path "$PKG" 2>/dev/null | head -n 1 | sed 's/^package://')
INST_MD5=""
[ -n "$INSTALLED" ] && [ -f "$INSTALLED" ] && INST_MD5=$(md5sum "$INSTALLED" 2>/dev/null | awk '{print $1}')
# 已安装的 APK 内容一致就绝不再 pm install。重复 install 会触发 LSPosed 重读模块，
# 正是 apk_path 被清空 / 模块几分钟后自动关闭的常见触发点。
if [ -n "$MD5" ] && [ "$MD5" = "$INST_MD5" ]; then
  echo "$MD5" > "$MARK"
  exit 0
fi
# 少数 SELinux 场景下读不到 /data/app 里的 base.apk，用文件大小兜底，避免每次开机重装；
# 只在 md5 读不到时兜底，md5 明确不同就照常更新。
if [ -z "$INST_MD5" ] && [ -n "$INSTALLED" ] && [ -f "$INSTALLED" ]; then
  INST_SIZE=$(wc -c < "$INSTALLED" 2>/dev/null | tr -d ' ')
  if [ "$INST_SIZE" = "$SIZE" ]; then
    echo "size:$SIZE" > "$MARK"
    exit 0
  fi
fi
if [ -z "$INSTALLED" ]; then
  R=$(pm install -r "$APK" 2>&1)
else
  R=$(pm install -r -d "$APK" 2>&1)
fi
echo "$(date '+%m-%d %H:%M:%S') install-apk size=$SIZE md5=$MD5 installed_md5=${INST_MD5:-none} result=$R" >> "$STATE/boot.log"
NEW_PATH=$(pm path "$PKG" 2>/dev/null | head -n 1 | sed 's/^package://')
NEW_MD5=""
[ -n "$NEW_PATH" ] && [ -f "$NEW_PATH" ] && NEW_MD5=$(md5sum "$NEW_PATH" 2>/dev/null | awk '{print $1}')
if [ -n "$MD5" ] && [ "$NEW_MD5" = "$MD5" ]; then
  echo "$MD5" > "$MARK"
fi
exit 0
