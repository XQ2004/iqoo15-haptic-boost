#!/system/bin/sh
# 把面板登记进 LSPosed：只负责「首次插入 + 确保启用 + 确保 system 作用域」。
# 关键原则：
#  1) 默认锁定启用（haptic_boost_lock_lsp=1），因为 LSPosed 在包更新/重装后
#     会把 apk_path 清空并自动关模块；只有用户显式把 lock 设为 0 才尊重关闭。
#  2) sqlite3 缺失 / DB 不可写 / APK 未装时写失败标记，供 lsp-repair 判断，绝不静默。
#  3) 只有真正发生变更时才写 state/lsp_changed，避免每次开机都触发软重启。
MODDIR=${0%/*}; MODDIR=${MODDIR%/bin}
. "$MODDIR/bin/common.sh"
PKG=com.coldbrew.hapticboost
FORCE_ENABLE=${FORCE_ENABLE:-0}
DB=/data/adb/lspd/config/modules_config.db
OUT="$STATE/lsp-setup.log"
mkdir -p "$STATE" 2>/dev/null

say() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$OUT"; }
fail() {
  say "FAIL $*"
  echo "$*" > "$STATE/lsp_setup_failed"
  rm -f "$STATE/lsp_registered" "$STATE/lsp_disabled" "$STATE/lsp_changed"
  exit 0
}
ok() {
  say "OK $*"
  rm -f "$STATE/lsp_setup_failed" "$STATE/lsp_disabled"
  echo 1 > "$STATE/lsp_registered"
  exit 0
}

[ -f "$DB" ] || fail "no_lsp_db"

SQLITE=""
for c in "$(command -v sqlite3 2>/dev/null)" /system/bin/sqlite3 /system/xbin/sqlite3 /data/adb/ksu/bin/sqlite3 /data/adb/magisk/sqlite3; do
  [ -n "$c" ] && [ -x "$c" ] && { SQLITE="$c"; break; }
done
[ -n "$SQLITE" ] || fail "no_sqlite3"

APK_PATH=$(pm path "$PKG" 2>/dev/null | head -n 1 | sed 's/^package://')
[ -n "$APK_PATH" ] || fail "apk_not_installed"

q() { "$SQLITE" "$DB" "$1" 2>/dev/null; }
ROWS=$(q "select count(*) from modules where module_pkg_name='$PKG';")
CUR=$(q "select apk_path from modules where module_pkg_name='$PKG';")
EN=$(q "select enabled from modules_state where module_pkg_name='$PKG' and user_id=0;")
SC=$(q "select count(*) from scope where module_pkg_name='$PKG' and app_pkg_name='system' and user_id=0;")
# 默认锁定启用；用户要主动关闭模块时先 settings put global haptic_boost_lock_lsp 0
USER_LOCK=$(settings get global haptic_boost_lock_lsp 2>/dev/null | tr -d '\r')
[ "$USER_LOCK" = "0" ] || USER_LOCK=1
# LSPosed 在包更新/重装时可能把 apk_path 清空。行还在但路径为空时，
# 必须 UPDATE 修复，不能按“新模块”去 INSERT（会 UNIQUE 冲突，模块随后被 LSPosed 关掉）。
EMPTY_PATH=0
[ "$ROWS" = "1" ] && [ -z "$CUR" ] && EMPTY_PATH=1
# 不同 LSPosed 版本的 modules_state 可能没有 scope_request_blocked 列，按实际 schema 生成 SQL
BLOCKED=$(q "select count(*) from pragma_table_info('modules_state') where name='scope_request_blocked';")
[ "$BLOCKED" = "1" ] || BLOCKED=0

# 只有用户显式 lock=0 且路径正常时才尊重关闭；
# lock=1 时 enabled=0 视为 LSPosed 自动关闭，直接拉回启用。
if [ "$EN" = "0" ] && [ "$EMPTY_PATH" = "0" ] && [ "$USER_LOCK" = "0" ] && [ "$FORCE_ENABLE" != "1" ]; then
  say "module disabled by user (lock=0), respect it"
  echo 1 > "$STATE/lsp_disabled"
  rm -f "$STATE/lsp_registered" "$STATE/lsp_setup_failed" "$STATE/lsp_changed"
  exit 0
fi
if [ "$EN" = "0" ] && [ "$USER_LOCK" = "1" ]; then
  say "enabled=0 but lock=1 -> force re-enable"
fi

CHANGED=0
[ "$EMPTY_PATH" = "1" ] && say "detected empty apk_path, will repair"
[ "$CUR" = "$APK_PATH" ] || CHANGED=1
[ "$EN" = "1" ] || CHANGED=1
[ "$SC" = "1" ] || CHANGED=1
if [ "$CHANGED" = "0" ]; then
  rm -f "$STATE/lsp_changed"
  ok "already registered"
fi

SQL="$STATE/lsp_setup.sql"
{
  echo "PRAGMA busy_timeout=5000;"
  if [ "$ROWS" = "1" ]; then
    echo "UPDATE modules SET apk_path='$APK_PATH' WHERE module_pkg_name='$PKG';"
  else
    echo "INSERT INTO modules(module_pkg_name,apk_path) VALUES('$PKG','$APK_PATH');"
  fi
  if [ -n "$EN" ]; then
    if [ "$BLOCKED" = "1" ]; then
      echo "UPDATE modules_state SET enabled=1, scope_request_blocked=0 WHERE module_pkg_name='$PKG' AND user_id=0;"
    else
      echo "UPDATE modules_state SET enabled=1 WHERE module_pkg_name='$PKG' AND user_id=0;"
    fi
  else
    if [ "$BLOCKED" = "1" ]; then
      echo "INSERT INTO modules_state(module_pkg_name,user_id,enabled,scope_request_blocked) VALUES('$PKG',0,1,0);"
    else
      echo "INSERT INTO modules_state(module_pkg_name,user_id,enabled) VALUES('$PKG',0,1);"
    fi
  fi
  echo "INSERT OR IGNORE INTO scope(module_pkg_name,app_pkg_name,user_id) VALUES('$PKG','system',0);"
  echo "PRAGMA wal_checkpoint(TRUNCATE);"
} > "$SQL"

if "$SQLITE" "$DB" < "$SQL" >> "$OUT" 2>&1; then
  EN2=$(q "select enabled from modules_state where module_pkg_name='$PKG' and user_id=0;")
  SC2=$(q "select count(*) from scope where module_pkg_name='$PKG' and app_pkg_name='system' and user_id=0;")
  if [ "$EN2" = "1" ] && [ "$SC2" = "1" ]; then
    # 仅修复空 apk_path（模块本来 enabled=1）不需要软重载；
    # 重新启用/首次登记才写 lsp_changed，交给 lsp-repair 跑 1 轮。
    if [ "$EMPTY_PATH" = "1" ] && [ "$EN" = "1" ] && [ "$SC" = "1" ]; then
      say "empty apk_path repaired without reload"
    else
      echo 1 > "$STATE/lsp_changed"
    fi
    say "registered apk=$APK_PATH"
    ok "registered"
  fi
  fail "verify_failed en=$EN2 scope=$SC2"
fi
fail "sqlite_failed"
