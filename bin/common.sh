# shellcheck shell=sh
MODDIR=${MODDIR:-/data/adb/modules/haptic_boost_v2505a}
STATE="$MODDIR/state"

# 参数表路径并不总在 /vendor/etc：V2301A(iQOO Neo8) 的适配报告里就没抓到该文件。
# 先按常见路径探测，再在 vendor/odm/system_ext/product 下浅层查找；找不到时保留默认路径，
# 由 apply.sh 输出 NO_CONFIG 直接退出，避免对着不存在的目标做 bind mount。
find_haptic_config() {
  for p in \
    /vendor/etc/Hapticsconfig.xml \
    /vendor/etc/haptics/Hapticsconfig.xml \
    /vendor/etc/vivo/Hapticsconfig.xml \
    /odm/etc/Hapticsconfig.xml \
    /system_ext/etc/Hapticsconfig.xml \
    /product/etc/Hapticsconfig.xml; do
    [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  find /vendor /odm /system_ext /product -maxdepth 6 -type f -name 'Hapticsconfig.xml' 2>/dev/null | head -n 1
}

TARGET=${HAPTIC_TARGET:-$(find_haptic_config)}
TARGET_FOUND=0
[ -n "$TARGET" ] && TARGET_FOUND=1
[ -n "$TARGET" ] || TARGET=/vendor/etc/Hapticsconfig.xml
mkdir -p "$STATE" 2>/dev/null

cur_level() { cat "$STATE/level" 2>/dev/null || echo 2; }
is_mounted() { grep -q " $TARGET " /proc/mounts 2>/dev/null; }

# 指纹(com.vivo.fingerprintui)、输入法(当前 default_input_method)以及侧边栏/
# 上滑后台相关包(systemuiplugin/card/globaldragdrop)的 VivoEffectIDSegment 默认不在
# 白名单里，只会走原厂轻振。这里追加进 Hook 白名单，保留用户已自定义的列表；
# 由 service.sh 开机调用、apply.sh 每次切档调用。Hook 侧 3 秒 TTL 自动生效。
ensure_vendor_pkgs() {
  cur=$(settings get global haptic_boost_vendor_pkgs 2>/dev/null | tr -d '\r')
  if [ -z "$cur" ] || [ "$cur" = "null" ]; then
    cur="com.android.systemui,com.bbk.launcher2,com.vivo.upslide,com.android.launcher3,com.android.quickstep"
  fi
  ime=$(settings get secure default_input_method 2>/dev/null | tr -d '\r' | cut -d/ -f1)
  case "$ime" in com.*) ;; *) ime= ;; esac
  # 侧边栏(upslide/systemuiplugin/card)、上滑后台、输入法、指纹：统一进 HEAVY 白名单
  for p in com.vivo.fingerprintui "$ime" com.vivo.systemuiplugin com.vivo.card com.vivo.globaldragdrop; do
    [ -n "$p" ] || continue
    case ",$cur," in
      *",$p,"*) ;;
      *) cur="$cur,$p" ;;
    esac
  done
  settings put global haptic_boost_vendor_pkgs "$cur" 2>/dev/null
}


# HAL 进程名在部分机型/版本上不同，按常见名字与进程表兜底
hal_pid() {
  for n in vendor.vivo.hardware.vibrator.custom.service vendor.vibrator-default vendor.vibrator vendor.vivo.hardware.vibrator@1.0-service vibrator-service android.hardware.vibrator-service; do
    p=$(pidof "$n" 2>/dev/null)
    [ -n "$p" ] && { echo "$p"; return; }
  done
  ps -A -o PID,NAME 2>/dev/null | grep -iE 'vendor.*vibrator|vibrator-default|vibrator-service|haptic' | grep -viE 'manager|4d|external|grep' | awk '{print $1}' | head -1
}

model_name() { getprop ro.product.model 2>/dev/null | tr -d ' \r\n'; }

# 机型档案：V2546A = iQOO 15 Ultra(战锤 MAX 双轴 091640，X/Z 双向)；当前 v2546a 四档由 V2505A L3 派生，真实原厂表待 dump-stock 抓取
# V2505A = iQOO 15(128.7Hz)；V2301A = iQOO Neo8(单马达，实测 168.5Hz，无原厂表，通用表单通道基线)
profile_for() {
  m=$(getprop ro.product.model 2>/dev/null)
  d=$(getprop ro.product.device 2>/dev/null)
  n=$(getprop ro.product.name 2>/dev/null)
  case "$m|$d|$n" in
    *V2546A*|*PD2546*) echo v2546a ;;
    *V2505A*|*PD2505*) echo v2505a ;;
    *V2301A*|*PD2301*) echo v2301a ;;
    *) echo generic ;;
  esac
}

get_profile() {
  if [ -s "$STATE/profile_override" ]; then
    p=$(cat "$STATE/profile_override" 2>/dev/null | tr -d ' \r\n')
    if [ -n "$p" ] && [ -d "$MODDIR/config/$p" ]; then echo "$p"; return; fi
  fi
  profile_for
}

# 读内核实测谐振：lra_frequency_hz 形如 "128 Hz"，cali_f0 形如 "freqency#ok#128.7#..."
read_f0_hz() {
  for f in /sys/class/qcom-haptics/lra_frequency_hz /sys/class/qcom-haptics/cali_f0; do
    [ -r "$f" ] || continue
    v=$(cat "$f" 2>/dev/null)
    hz=$(printf '%s\n' "$v" | sed -n 's/^[^0-9]*\([0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}\).*$/\1/p' | head -n 1)
    [ -n "$hz" ] || continue
    ok=$(awk -v h="$hz" 'BEGIN{print (h>=50 && h<=300) ? 1 : 0}')
    [ "$ok" = "1" ] && { echo "$hz"; return; }
  done
}

# 把选中档位 XML 变成 active.xml：按实测/档案谐振改写 f0 起点；测不到就关掉 f0_tracking
prepare_xml() {
  src=$1; dst=$2; prof=$3
  hz=$(read_f0_hz)
  if [ -z "$hz" ]; then
    case "$prof" in
      v2505a) hz=128.7 ;;
      v2546a) hz=136 ;;  # 旧表被 prepare_xml 写成 139264；实测优先，读不到用 136Hz 兜底
      v2301a) hz=168.5 ;; # cali_f0 168.5Hz；国产单马达，无原厂表
      *) hz= ;;
    esac
  fi
  q20=0; have=0
  if [ -n "$hz" ]; then
    q20=$(awk -v h="$hz" 'BEGIN{printf "%d", h*1024+0.5}')
    case "$q20" in ''|0) have=0 ;; *) have=1 ;; esac
  fi
  awk -v q20="$q20" -v have="$have" '
  {
    if ($0 ~ /<f0_tracking_en>1<\/f0_tracking_en>/) {
      if (have == 0) {
        sub(/<f0_tracking_en>1<\/f0_tracking_en>/, "<f0_tracking_en>0</f0_tracking_en>")
        f0 = 0
        print
        next
      }
      f0 = 1
    }
    if (f0 == 1 && $0 ~ /<wavegen_fstart_hz_q20>[0-9]+<\/wavegen_fstart_hz_q20>/) {
      sub(/<wavegen_fstart_hz_q20>[0-9]+<\/wavegen_fstart_hz_q20>/, "<wavegen_fstart_hz_q20>" q20 "</wavegen_fstart_hz_q20>")
      f0 = 0
    }
    print
  }' "$src" > "$dst" || return 1
  printf '%s\n' "${hz:-unknown}" > "$STATE/f0"
  printf '%s %s\n' "$have" "$q20" > "$STATE/f0_q20"
  return 0
}
