#!/system/bin/sh
# 用法: apply.sh [0|1|2|3|4]   0=关闭 1=轻度 2=标准 3=激进 4=极限
# 自动按机型选择 config/<profile>/levelN.xml，并在挂载前按实测谐振改写 f0
MODDIR=${0%/*}; MODDIR=${MODDIR%/bin}
. "$MODDIR/bin/common.sh"

LVL=${1:-$(cur_level)}
case "$LVL" in
  0|1|2|3|4) ;;
  *) LVL=2 ;;
esac

PROFILE=$(get_profile)
# 保证指纹包在 Hook 白名单（保留用户已有列表）
ensure_vendor_pkgs

# 首次挂载前保存真正的原厂表：bind mount 一旦挂上，/vendor/etc/Hapticsconfig.xml
# 读到的就是我们的档位表，报告里也会把它当成"原厂"。已有 stock.xml 不覆盖；
# 已挂载的设备用 bin/dump-stock.sh --force 现场抓取。
if ! is_mounted && [ ! -s "$STATE/stock.xml" ] && [ -f "$TARGET" ]; then
  if cp "$TARGET" "$STATE/stock.xml" 2>/dev/null; then
    md5sum "$STATE/stock.xml" 2>/dev/null | awk '{print $1}' > "$STATE/stock.md5"
    echo "STOCK_SAVED $(wc -c < "$STATE/stock.xml" | tr -d ' ') bytes"
  fi
fi

if [ "$LVL" = "0" ]; then
  is_mounted && umount "$TARGET" 2>/dev/null
  echo 0 > "$STATE/level"
  echo "$PROFILE" > "$STATE/profile"
  P=$(hal_pid)
  [ -n "$P" ] && kill "$P" 2>/dev/null
  echo "OK level=0 profile=$PROFILE"
  exit 0
fi

# 目标不存在时不要 mount：Neo8 的报告里 /vendor/etc/Hapticsconfig.xml 并不存在。
# 这类机型没有 HAL 参数表，但 LSPosed Hook 仍然可用；把 L1-L4 映射成 Hook 档位，
# 写 settings 后由 Hook 侧 3 秒 TTL 生效，面板仍按成功处理，不再弹 NO_CONFIG。
apply_hook_only() {
  case "$LVL" in
    1) ST=1.15; AT=1.05; UH=0; VH=0; HM=0;   HA=255;;
    2) ST=1.30; AT=1.15; UH=0; VH=0; HM=22;  HA=140;;
    3) ST=1.45; AT=1.30; UH=1; VH=1; HM=0;   HA=255;;
    4) ST=1.60; AT=1.45; UH=1; VH=1; HM=0;   HA=255;;
  esac
  settings put global haptic_boost_enable 1 2>/dev/null
  settings put global haptic_boost_scale_touch "$ST" 2>/dev/null
  settings put global haptic_boost_amp_touch "$AT" 2>/dev/null
  settings put global haptic_boost_ui_heavy "$UH" 2>/dev/null
  settings put global haptic_boost_ui_effect 5 2>/dev/null
  settings put global haptic_boost_ui_strength 2 2>/dev/null
  settings put global haptic_boost_vendor "$VH" 2>/dev/null
  settings put global haptic_boost_vendor_mode 1 2>/dev/null
  settings put global haptic_boost_hammer_ms "$HM" 2>/dev/null
  settings put global haptic_boost_hammer_amp "$HA" 2>/dev/null
  settings put global haptic_boost_hammer_double 0 2>/dev/null
  settings put global haptic_boost_hammer_gap 10 2>/dev/null
  echo "$LVL" > "$STATE/level"
  echo "$PROFILE" > "$STATE/profile"
  echo "OK level=$LVL hook_only=1 profile=$PROFILE"
}

if [ ! -f "$TARGET" ]; then
  echo "NO_CONFIG target=$TARGET profile=$PROFILE -> hook-only level $LVL"
  apply_hook_only
  exit 0
fi

SRC="$MODDIR/config/$PROFILE/level$LVL.xml"
[ -f "$SRC" ] || SRC="$MODDIR/config/generic/level$LVL.xml"
[ -f "$SRC" ] || { echo "MISSING $SRC"; exit 1; }

prepare_xml "$SRC" "$STATE/active.xml" "$PROFILE" || { echo "PREPARE_FAIL"; exit 1; }
F0=$(cat "$STATE/f0" 2>/dev/null)

# bind 源放 /data/local/tmp：shell_data_file 对 HAL 可读；模块目录是 ksu_file，
# 直接 bind 可能被 SELinux 拦住（HAL 打不开配置）。
TMPXML=/data/local/tmp/haptic_boost_active.xml
mkdir -p /data/local/tmp 2>/dev/null
cp "$STATE/active.xml" "$TMPXML" || { echo "COPY_FAIL"; exit 1; }
chmod 644 "$TMPXML" 2>/dev/null

if is_mounted; then
  umount "$TARGET" 2>/dev/null
fi
mount --bind "$TMPXML" "$TARGET" 2>/dev/null || { echo "BIND_FAIL"; exit 1; }
is_mounted || { echo "BIND_FAIL"; exit 1; }
echo "$LVL" > "$STATE/level"
echo "$PROFILE" > "$STATE/profile"

P=$(hal_pid)
if [ -n "$P" ]; then
  kill "$P" 2>/dev/null
  sleep 1
  kill -0 "$P" 2>/dev/null && kill -9 "$P" 2>/dev/null
fi
echo "OK level=$LVL profile=$PROFILE f0=${F0:-unknown} hal_pid=$(hal_pid)"
