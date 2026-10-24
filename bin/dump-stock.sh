#!/system/bin/sh
# 抓取真正的原厂 Hapticsconfig.xml
# 场景：模块已经 bind mount 了档位表，/vendor/etc/Hapticsconfig.xml 读到的是我们的表。
# 本脚本临时 umount，读取下面的原厂文件，再恢复当前档位挂载。
# 用法: sh dump-stock.sh [--force]
#   --force  忽略 state/stock.xml，重新从 /vendor 读取
MODDIR=${0%/*}; MODDIR=${MODDIR%/bin}
. "$MODDIR/bin/common.sh"

OUT_DIR=/storage/emulated/0/Download
[ -d "$OUT_DIR" ] || OUT_DIR=/sdcard/Download
mkdir -p "$OUT_DIR" 2>/dev/null

MODEL=$(model_name)
[ -n "$MODEL" ] || MODEL=unknown
TS=$(date +%Y%m%d_%H%M%S)
OUT="$OUT_DIR/Hapticsconfig_${MODEL}_stock_${TS}.xml"
STOCK="$STATE/stock.xml"

[ -f "$TARGET" ] || { echo "NO_TARGET $TARGET"; exit 1; }

remount_active() {
  [ -s "$STATE/active.xml" ] || return 0
  TMPXML=/data/local/tmp/haptic_boost_active.xml
  cp "$STATE/active.xml" "$TMPXML" 2>/dev/null || return 0
  chmod 644 "$TMPXML" 2>/dev/null
  mount --bind "$TMPXML" "$TARGET" 2>/dev/null
  P=$(hal_pid)
  [ -n "$P" ] && kill "$P" 2>/dev/null
}

# 已有可信备份：直接导出，除非 --force
if [ -s "$STOCK" ] && [ "$1" != "--force" ]; then
  cp "$STOCK" "$OUT" 2>/dev/null && chmod 644 "$OUT" 2>/dev/null
  SZ=$(wc -c < "$OUT" 2>/dev/null | tr -d ' ')
  MD5=$(md5sum "$OUT" 2>/dev/null | awk '{print $1}')
  echo "STOCK_OK $OUT ${SZ} bytes md5=$MD5 (from state/stock.xml)"
  exit 0
fi

WAS_MOUNTED=0
if is_mounted; then
  WAS_MOUNTED=1
  umount "$TARGET" 2>/dev/null || umount -l "$TARGET" 2>/dev/null
  sleep 1
fi

if is_mounted; then
  echo "STOCK_FAIL umount failed; still mounted"
  exit 1
fi

if [ ! -f "$TARGET" ]; then
  echo "STOCK_FAIL target missing after umount"
  [ "$WAS_MOUNTED" = "1" ] && remount_active
  exit 1
fi

cp "$TARGET" "$STOCK" 2>/dev/null || { echo "STOCK_FAIL copy state"; [ "$WAS_MOUNTED" = "1" ] && remount_active; exit 1; }
cp "$TARGET" "$OUT" 2>/dev/null || { echo "STOCK_FAIL copy output"; [ "$WAS_MOUNTED" = "1" ] && remount_active; exit 1; }
chmod 644 "$OUT" 2>/dev/null
chown media_rw:media_rw "$OUT" 2>/dev/null

SZ=$(wc -c < "$OUT" 2>/dev/null | tr -d ' ')
MD5=$(md5sum "$OUT" 2>/dev/null | awk '{print $1}')
printf '%s\n' "$MD5" > "$STATE/stock.md5" 2>/dev/null

# 恢复当前档位挂载
[ "$WAS_MOUNTED" = "1" ] && remount_active

echo "STOCK_OK $OUT ${SZ} bytes md5=$MD5"
