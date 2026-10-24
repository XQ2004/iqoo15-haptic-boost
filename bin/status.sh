#!/system/bin/sh
MODDIR=${0%/*}; MODDIR=${MODDIR%/bin}
. "$MODDIR/bin/common.sh"
echo "level=$(cur_level) mounted=$(is_mounted && echo 1 || echo 0) hal_pid=$(hal_pid)"
echo "model=$(model_name) profile=$(cat "$STATE/profile" 2>/dev/null || get_profile) f0=$(cat "$STATE/f0" 2>/dev/null || echo -)"
echo "target=$(ls -l "$TARGET" 2>/dev/null | awk '{print $5" bytes"}')"
grep " $TARGET " /proc/mounts 2>/dev/null | head -1
echo "lra_freq=$(cat /sys/class/qcom-haptics/lra_frequency_hz 2>/dev/null)"
echo "impedance=$(cat /sys/class/qcom-haptics/lra_impedance 2>/dev/null)"
