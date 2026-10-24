#!/system/bin/sh
# KSU 模块「执行」按钮: 直接打开控制面板。
# 不再切档、不再触发试震、不再重启 HAL —— 避免点击执行时马达被反复触发/卡住。
MODDIR=${0%/*}
PKG=com.coldbrew.hapticboost
APK="$MODDIR/apk/HapticBoostLSP.apk"

# 先取消可能残留的震动，保证点执行不会延续上一次的长振
cmd vibrator_manager cancel >/dev/null 2>&1

# 面板被卸载时从模块内置 APK 补装
if ! pm path "$PKG" >/dev/null 2>&1; then
  [ -f "$APK" ] && pm install -r -d "$APK" >/dev/null 2>&1
fi

if pm path "$PKG" >/dev/null 2>&1; then
  am start -n "$PKG/.MainActivity" >/dev/null 2>&1 \
    || monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  echo "已打开 振动增强"
else
  echo "面板未安装，请重新刷入模块"
fi
exit 0
