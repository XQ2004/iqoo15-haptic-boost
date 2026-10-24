#!/system/bin/sh
MODPATH=${MODPATH:-$1}
[ -d "$MODPATH/bin" ] && chmod 755 "$MODPATH"/*.sh "$MODPATH"/bin/*.sh 2>/dev/null

APK="$MODPATH/apk/HapticBoostLSP.apk"
if [ -f "$APK" ] && command -v pm >/dev/null 2>&1; then
  R=$(pm install -r -d "$APK" 2>&1)
  echo "iQOO 振动增强: 面板 APK 安装 -> $R"
  mkdir -p "$MODPATH/state" 2>/dev/null
  case "$R" in
    *Success*)
      wc -c < "$APK" | tr -d ' ' > "$MODPATH/state/apk_size"
      md5sum "$APK" 2>/dev/null | awk '{print $1}' > "$MODPATH/state/apk_md5"
      MODDIR="$MODPATH" sh "$MODPATH/bin/lsp-setup.sh" >/dev/null 2>&1
      if [ -f "$MODPATH/state/lsp_registered" ]; then
        echo "iQOO 振动增强: 已登记进 LSPosed(启用 + 作用域=系统框架)"
      else
        echo "iQOO 振动增强: 自动登记未完成($(cat "$MODPATH/state/lsp_setup_failed" 2>/dev/null))，请在 LSPosed 里手动启用模块并勾选系统框架"
      fi
      ;;
  esac
fi

echo "iQOO 振动增强: 参数表已就位 (L1-L4, 自动识别 V2505A / V2546A / V2301A / 通用), 重启后可在面板切换档位"
echo "iQOO 振动增强: 首次挂载前会自动备份原厂表到 state/stock.xml；已挂载设备可运行 bin/dump-stock.sh --force 抓原厂表"
