#!/system/bin/sh
# 振动适配报告生成器 —— 输出到手机 Download 目录, 供换机移植适配用
# 用法: sh report.sh            (root 下信息最全, 无 root 也能出大部分)

MODDIR=${0%/*}
case "$MODDIR" in */bin) MODDIR=$(cd "$MODDIR/.." && pwd);; esac
[ -f "$MODDIR/module.prop" ] || MODDIR=/data/adb/modules/haptic_boost_v2505a

OUT_DIR=/storage/emulated/0/Download
[ -d "$OUT_DIR" ] || OUT_DIR=/sdcard/Download
mkdir -p "$OUT_DIR" 2>/dev/null

MODEL=$(getprop ro.product.model 2>/dev/null | tr -d " \r\n")
[ -z "$MODEL" ] && MODEL=$(getprop ro.product.device 2>/dev/null | tr -d " \r\n")
[ -z "$MODEL" ] && MODEL=unknown
TS=$(date +%Y%m%d_%H%M%S)
OUT="$OUT_DIR/haptic_adapt_${MODEL}_${TS}.txt"

sec() { echo ""; echo "===== $* ====="; }

{
echo "# 振动适配报告 (haptic adaptation report)"
echo "generated: $(date "+%Y-%m-%d %H:%M:%S %Z")"
echo "report_version: 4"
echo "root_uid: $(id -u 2>/dev/null)"
echo "selinux: $(getenforce 2>/dev/null)"
MV=$(grep -m1 "^version=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)
[ -n "$MV" ] || MV=$(grep -m1 "^version=" /data/adb/modules/haptic_boost_v2505a/module.prop 2>/dev/null | cut -d= -f2)
echo "module_version: ${MV:-unknown}"

sec "1 device props"
for k in ro.product.brand ro.product.manufacturer ro.product.model ro.product.device ro.product.name ro.board.platform ro.hardware ro.boot.hardware ro.build.version.release ro.build.version.sdk ro.build.display.id ro.build.fingerprint ro.build.date.utc ro.vivo.os.version ro.vivo.rom.version ro.miui.ui.version.name ro.mi.os.version.name ro.build.version.oplusrom ro.build.version.opporom ro.oplus.version ro.build.version.oneui ro.build.version.emui; do
  v=$(getprop "$k" 2>/dev/null)
  [ -n "$v" ] && printf "%s=%s\n" "$k" "$v"
done

sec "1b props matching vibrat/haptic/lra/motor"
getprop 2>/dev/null | grep -iE "vibrat|haptic|lra|motor" | head -40

sec "2 vibrator services / processes"
service list 2>/dev/null | grep -iE "vibrat|haptic"
ps -A 2>/dev/null | grep -iE "vibrat|haptic"
ps 2>/dev/null | grep -iE "vibrat|haptic"
echo "-- hal_pid candidates"
for n in vendor.vivo.hardware.vibrator.custom.service vendor.vibrator-default vendor.vibrator vibrator-service android.hardware.vibrator-service; do
  p=$(pidof "$n" 2>/dev/null); [ -n "$p" ] && echo "$n=$p"
done

sec "3 dumpsys vibrator_manager (head 130)"
dumpsys vibrator_manager 2>/dev/null | head -130

sec "3b cmd vibrator_manager usage"
cmd vibrator_manager 2>&1 | head -25

sec "4 recent vibrations (played/original)"
dumpsys vibrator_manager 2>/dev/null | grep -E "played:|original:" | tail -40

sec "5 haptics related files"
find /vendor /odm /system_ext /product -maxdepth 4 \( -iname "*haptic*" -o -iname "*vibrat*" \) 2>/dev/null | head -80

sec "6 config xml (stock preferred; max 4 files, <=200KB each)"
STOCK="$MODDIR/state/stock.xml"
if [ -s "$STOCK" ]; then
  sz=$(wc -c < "$STOCK" 2>/dev/null | tr -d " ")
  md=$(md5sum "$STOCK" 2>/dev/null | awk '{print $1}')
  echo "--- $STOCK (STOCK BACKUP, $sz bytes md5=$md)"
  if [ "${sz:-0}" -le 200000 ] 2>/dev/null; then cat "$STOCK" 2>/dev/null; else echo "(too large, skipped)"; fi
  LIVE=/vendor/etc/Hapticsconfig.xml
  if [ -f "$LIVE" ]; then
    lmd=$(md5sum "$LIVE" 2>/dev/null | awk '{print $1}')
    if [ "$lmd" != "$md" ]; then
      lsz=$(wc -c < "$LIVE" 2>/dev/null | tr -d " ")
      echo "--- LIVE $LIVE (may be module bind mount, $lsz bytes md5=$lmd)"
      if [ "${lsz:-0}" -le 200000 ] 2>/dev/null; then cat "$LIVE" 2>/dev/null; fi
    fi
  fi
else
  echo "!!! no state/stock.xml; live config below may be the module's bind mount, NOT stock !!!"
  n=0
  for f in $(find /vendor /odm /system_ext -maxdepth 4 -iname "*haptic*.xml" 2>/dev/null); do
    n=$((n+1))
    [ $n -gt 4 ] && break
    sz=$(wc -c < "$f" 2>/dev/null | tr -d " ")
    md=$(md5sum "$f" 2>/dev/null | awk '{print $1}')
    echo "--- LIVE $f ($sz bytes md5=$md)"
    if [ "${sz:-0}" -le 200000 ] 2>/dev/null; then cat "$f" 2>/dev/null; else echo "(too large, skipped)"; fi
  done
fi

sec "7 kernel / sysfs"
echo "> /sys/class/qcom-haptics"
ls /sys/class/qcom-haptics 2>/dev/null | head -40
echo "> /sys/class/leds (vib)"
ls /sys/class/leds 2>/dev/null | grep -iE "vib|haptic" | head -20
for f in /sys/class/qcom-haptics/lra_frequency_hz /sys/class/qcom-haptics/cali_f0 /sys/class/qcom-haptics/cali_f0_resis /sys/class/qcom-haptics/the_num_of_vibrator /sys/class/qcom-haptics/lra_impedance /sys/class/qcom-haptics/dyna_cali; do
  if [ -e "$f" ]; then echo "$f = $(cat "$f" 2>&1)"; fi
done
ls -lZ /dev/*haptic* 2>/dev/null

sec "8 packages seen in our trace"
if [ -f /data/system/haptic_boost_trace.log ]; then
  grep -oE "pkg=[^ ]+" /data/system/haptic_boost_trace.log 2>/dev/null | sort | uniq -c | sort -rn | head -20
  echo "-- vendor segment classes seen:"
  grep -oE "cls=.*" /data/system/haptic_boost_trace.log 2>/dev/null | tail -6
else
  echo "(no trace)"
fi

sec "9 lsposed"
lspctl --json status 2>/dev/null | head -30
DB=/data/adb/lspd/config/modules_config.db
if [ -f "$DB" ]; then
  sqlite3 "$DB" "select module_pkg_name, apk_path from modules;" 2>/dev/null
  sqlite3 "$DB" "select module_pkg_name, user_id, enabled from modules_state;" 2>/dev/null
  sqlite3 "$DB" "select module_pkg_name, app_pkg_name, user_id from scope;" 2>/dev/null
fi

sec "10 our module state"
ls -l "$MODDIR" 2>/dev/null | head -25
echo -n "state.level="; cat "$MODDIR/state/level" 2>/dev/null; echo
echo -n "state.profile="; cat "$MODDIR/state/profile" 2>/dev/null; echo
echo -n "state.f0="; cat "$MODDIR/state/f0" 2>/dev/null; echo
echo -n "state.f0_q20="; cat "$MODDIR/state/f0_q20" 2>/dev/null; echo
if [ -s "$MODDIR/state/stock.xml" ]; then
  echo -n "state.stock=yes "; wc -c < "$MODDIR/state/stock.xml" 2>/dev/null | tr -d " "; echo
else
  echo "state.stock=no"
fi
echo -n "state.stock_md5="; cat "$MODDIR/state/stock.md5" 2>/dev/null; echo
echo "note: 如果下面的 mount 行是 f2fs (rw,...)，说明 /vendor/etc/Hapticsconfig.xml 被模块 bind mount 覆盖；section 6 的 LIVE 不是原厂表。"
mount 2>/dev/null | grep -i hapticsconfig
settings list global 2>/dev/null | grep haptic_boost
echo "--- lsp-setup.log tail 20 ---"; tail -20 "$MODDIR/state/lsp-setup.log" 2>/dev/null
echo "--- lsp-repair.log tail 20 ---"; tail -20 "$MODDIR/state/lsp-repair.log" 2>/dev/null
echo "--- lsp-watch.log tail 20 ---"; tail -20 "$MODDIR/state/lsp-watch.log" 2>/dev/null
echo "--- newest lsp-disable snapshot tail 120 ---"
SNAP=$(ls -t "$MODDIR"/state/lsp-disable-*.log 2>/dev/null | head -n 1)
[ -n "$SNAP" ] && { echo "snapshot=$SNAP"; tail -120 "$SNAP"; }

sec "11 trace tail 40"
tail -40 /data/system/haptic_boost_trace.log 2>/dev/null

sec "12 framework jars"
ls -l /system/framework/framework.jar /system/framework/services.jar 2>/dev/null
getprop 2>/dev/null | grep -iE "dalvik.vm.isa|ro.zygote" | head -6
} > "$OUT" 2>&1

size=$(wc -c < "$OUT" 2>/dev/null | tr -d " ")
echo "REPORT_OK $OUT $size"
