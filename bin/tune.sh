#!/system/bin/sh
# runtime preset for LSPosed hook (no reboot, 3s TTL refresh)
case "${1:-}" in
  1|std|soft|standard)
    settings put global haptic_boost_scale_touch 1.10
    settings put global haptic_boost_amp_touch 1.05
    settings put global haptic_boost_ui_heavy 0
    settings put global haptic_boost_vendor 0
    settings put global haptic_boost_hammer_ms 22
    settings put global haptic_boost_hammer_double 0
    settings put global haptic_boost_hammer_amp 140
    settings put global haptic_boost_hammer_gap 10
    settings put global haptic_boost_notify_mode 0
    settings put global haptic_boost_notify_amp 1.20
    settings put global haptic_boost_notify_strength 2
    echo "preset 1 · 标准: 22ms/0.55 轻触脉冲 (scale_touch=1.10 amp_touch=1.05 ui_heavy=0 vendor=0)" ;;
  2|heavy|hard|max)
    settings put global haptic_boost_scale_touch 1.60
    settings put global haptic_boost_amp_touch 1.30
    settings put global haptic_boost_ui_heavy 1
    settings put global haptic_boost_ui_effect 5
    settings put global haptic_boost_ui_strength 2
    settings put global haptic_boost_strength 2
    settings put global haptic_boost_vendor 1
    settings put global haptic_boost_vendor_mode 1
    settings put global haptic_boost_hammer_ms 0
    settings put global haptic_boost_hammer_double 0
    settings put global haptic_boost_notify_mode 1
    settings put global haptic_boost_notify_amp 1.30
    settings put global haptic_boost_notify_strength 2
    echo "preset 2 · 激进: 统一 HEAVY_CLICK(STRONG) (scale_touch=1.60 amp_touch=1.30 ui_heavy=1 vendor=1)" ;;
  notify4d)
    settings put global haptic_boost_notify_mode 1
    settings put global haptic_boost_notify_amp 1.30
    settings put global haptic_boost_notify_strength 2
    echo "notify: 4D 双马达立体" ;;
  notifylong)
    settings put global haptic_boost_notify_mode 2
    settings put global haptic_boost_notify_amp 1.45
    settings put global haptic_boost_notify_strength 2
    echo "notify: 4D + 长震" ;;
  notifyboost)
    settings put global haptic_boost_notify_mode 0
    settings put global haptic_boost_notify_amp 1.50
    settings put global haptic_boost_notify_strength 2
    echo "notify: 仅提幅度 x1.5" ;;
  notifynative)
    settings put global haptic_boost_notify_mode -1
    settings put global haptic_boost_notify_amp 1.00
    settings put global haptic_boost_notify_strength -1
    echo "notify: 原生" ;;
  hammer)
    settings put global haptic_boost_hammer_ms 45
    settings put global haptic_boost_hammer_double 0
    settings put global haptic_boost_hammer_amp 255
    settings put global haptic_boost_hammer_gap 10
    echo "gesture heavy boost on: 45ms 单发满振幅脉冲" ;;
  nohammer)
    settings put global haptic_boost_hammer_ms 0
    echo "hammer off" ;;
  off)
    settings put global haptic_boost_enable 0
    echo "hook disabled (haptic_boost_enable=0)" ;;
  on)
    settings put global haptic_boost_enable 1
    echo "hook enabled" ;;
  *)
    echo "usage: tune.sh 1|std(标准 22ms) 2|heavy(激进 HEAVY) |notify4d|notifylong|notifyboost|notifynative|hammer|nohammer|on|off";;
esac
