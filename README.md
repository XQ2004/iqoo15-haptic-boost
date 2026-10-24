# iQOO 振动增强 v3.2.12（KernelSU + LSPosed）

系统级振动增强模块：**HAL 参数表 + LSPosed Hook + 桌面面板**，全部运行时生效，不写入系统分区。

- 适用：vivo V2505A（iQOO 15，Android 16）、V2546A（iQOO 15 Ultra，双轴 X/Z；当前 v2546a 档由 V2505A L3 派生并顶满 HEAVY，真实原厂表待抓取）、V2301A（iQOO Neo8，单马达，实测 168.5Hz）；其它机型走通用档案。
- 面板包名：`com.coldbrew.hapticboost`（Miuix + Jetpack Compose，v4.2.0）。
- 模块 ID：`haptic_boost_v2505a`。

## 组成部分

1. **参数表（KSU）**
   - `config/level1..4.xml` 四档 Hapticsconfig 参数表，开机由 `post-fs-data.sh` / `apply.sh` 以 bind mount 挂到 `/vendor/etc/Hapticsconfig.xml`。
   - 只重定向到 `/data`，erofs 系统分区零写入；`umount` 即恢复原生。
   - L1 轻度 / L2 标准 / L3 强力 / L4 满振幅重击（默认 L4）。
   - 运行时按内核 `lra_frequency_hz` 对齐 f0，避免拿错频率硬跑。

2. **Hook（LSPosed，经典 Xposed API）**
   - `BoostModule` 注入 `system_server`：
     - `VibrationScaler.scale(VibrationEffect,int)`：幅度缩放、prebaked 改写、手势形态替换。
     - `VibrationScaler.getScaleFactor(int)` / `getEffectStrength(int)`：按 usage 分档。
     - `VibratorManagerService.vibrateInternal`：识别 vivo 私有 `VivoEffectIDSegment`，替换为 HEAVY_CLICK 或 THUD。
   - 通知 / 来电 / 消息走单独通道，可选原生、增强、4D 立体、4D 长震。
   - 配置键为 `Settings.Global` 的 `haptic_boost_*`，Hook 侧 3 秒 TTL。

3. **桌面面板（Miuix + Jetpack Compose）**
   - 四个 Tab：**模块 / 增强 / 试震 / 设置**。
   - 模块：单张 hero 卡（自绘图标 + ROOT/HOOK/档位三枚状态块 + 版本/进程/谐振明细 + 刷新），顶栏标题固定为「振动增强」；下方帮助卡直达设置页生成报告。
   - 增强：全局开关、手感两档（标准 = 22ms 轻触脉冲 / 激进 = 统一 HEAVY 重击）、手势形态（HEAVY 重击 / THUD 短促）、补充脉冲、通知/来电/消息、铃声跟随、音量键震动、参数表 L1–L4/关闭。
   - 试震：六个 prebaked 效果（轻点/双击/滴答/沉闷/弹出/重击）。
   - 设置：Miuix 主题（跟随系统/浅色/深色）、维护（重载 Hook、HAL、LRA、日志）、生成适配报告、清理残留、说明。
   - 面板只写 `Settings.Global` 和执行模块脚本，不含 Hook 代码。

## 主页改版（v3.2）

- 顶栏在模块页显示「振动增强」，不再与卡片内标题重复；其它 Tab 仍显示 模块/增强/试震/设置。
- 状态信息收进一张 hero 卡：左上自绘橙色 AppMark，右侧 HAPTIC ENGINE / 系统震感控制台 / Miuix + Compose · 零分区写入。
- ROOT、HOOK、档位改成三枚等宽状态块（主色 10% 底），一眼可读；版本、HAL 进程、马达谐振改为单行明细，刷新按钮收在右下。
- 帮助卡改为横向图标 + 两行说明 + 「去设置生成报告」；删除「关于」卡，页脚只留版本与日志路径。

## 执行按钮（v3.2.1）

- 模块管理页点「执行」不再切档、不再试震、也不再重启 HAL，直接打开面板。
- 打开前会先取消残留震动；面板被卸载时会用模块内置 APK 补装。
- 修复点执行时马达持续震动：旧脚本先 `apply.sh` 杀 HAL，再发 `prebaked 5` 试震，HAL 在振动中被杀会导致马达停不下来。

## V2546A 适配口径修正（v3.2.3）

- **重要更正**：v3.1 当初把 12:26 报告里的 `Hapticsconfig.xml`（21406B，md5 `078c236eebfdc0215aaa21b207c07072`）当成 V2546A 原厂表；复核发现它逐个 effect 都等于本模块的 **V2505A L3**（predefined 54/100/100、width 49、sharpness 52；compose 48/100/100、width 7、sharpness 70），只有 f0 被 `prepare_xml` 改成了 139264。
- 16:06 这份报告里的 21396B 表（md5 `b510a75620e6feb9f06439d827b2b428`）同样不是原厂表：它逐个 effect 都等于 **V2505A L2**（45/88/100、width 45、sharpness 60），只有 f0 是 138240。
- 结论：两份 V2546A 报告都是在模块 bind mount 生效时生成的，读到的都是我们自己的档位表，**V2546A 真实原厂表两次都没抓到**。`config/v2546a/level1..4.xml` 目前实质是「V2505A L3 再放大」的过渡档，不等同原厂调音。
- 修正手段：`apply.sh` 在首次挂载前把真正的原厂表备份到 `state/stock.xml`；已挂载设备运行 `bin/dump-stock.sh --force` 临时 umount 抓取后再恢复挂载；`report.sh` v4 优先输出 `state/stock.xml`，并对现场 LIVE 表标注「may be module bind mount」。
- 拿到真实 stock 后，再按同一套系数重生成 `config/v2546a/level1..4.xml`。

## 抓取 V2546A 原厂表

```bash
# 已经装了旧模块、当前 /vendor/etc/Hapticsconfig.xml 被挂载覆盖时：
adb shell su -c 'sh /data/adb/modules/haptic_boost_v2505a/bin/dump-stock.sh --force'
# 输出：/sdcard/Download/Hapticsconfig_V2546A_stock_<时间>.xml
```

- 刷入 v3.2.3 后重启，`post-fs-data` 会在挂载前自动备份 `state/stock.xml`，之后面板「生成适配报告」会优先带出这份 stock。
- 如果只想恢复原生表：面板参数表选「关闭」，或执行 `apply.sh 0`；不会改分区。

## V2301A 适配（v3.2.2）

- 适配报告来自 iQOO Neo8（V2301A / PD2301）：单马达，`/sys/class/qcom-haptics/the_num_of_vibrator=1`，`lra_frequency_hz=168 Hz`，`cali_f0=168.5Hz`（150.0–190.0 范围），阻抗 6250–7500 mΩ；只有 `/dev/vivo_haptic` 与 `/dev/vivo_haptic_core`，没有 vice 通道。
- 报告 section 6「config xml」为空：`/vendor`、`/odm`、`/system_ext` 下都没抓到 Hapticsconfig.xml。**没有原厂参数表可逐项复刻**，因此 v2301a 档案以通用单通道表为基线，只把 f0 起点对齐到 168.5Hz（q20=172544），运行时仍优先用 `lra_frequency_hz` / `cali_f0` 实测值。
- 四档沿用通用档位：L1 低幅轻触 → L4 满振幅长脉宽；属于「单马达 168.5Hz 通用增强」首版，不等同原厂调音。
- `bin/common.sh` 增加 `V2301A / PD2301 → v2301a` 识别；HAL 进程名兼容 `vendor.vivo.hardware.vibrator.custom.service`。
- 参数表路径改为自动探测：依次找 `/vendor/etc/Hapticsconfig.xml`、`/vendor/etc/haptics/...`、`/vendor/etc/vivo/...`、`/odm/etc/...`、`/system_ext/etc/...`、`/product/etc/...`，再 `find` 浅层搜索；找不到时不再对着不存在的目标 bind mount。
- 若该机确实没有参数表文件，`apply.sh` 会进入 **Hook-only 档位**（见下节），面板不再弹 `NO_CONFIG`。

## 无参数表机型：Hook-only 档位（v3.2.4）

V2301A（iQOO Neo8）这类机器 `/vendor/etc/Hapticsconfig.xml` 根本不存在，没有 HAL 参数表可挂，之前的 `apply.sh` 会直接输出 `NO_CONFIG`，面板就弹「切换失败」。v3.2.4 改成自动降级：

- 检测不到参数表时，L1–L4 不再尝试 mount，而是把四档映射成 Hook 参数并写入 `Settings.Global`：

| 档位 | scale_touch | amp_touch | ui_heavy | vendor 手势改写 | 补充脉冲 |
|---|---|---|---|---|---|
| L1 | 1.15 | 1.05 | 0 | 0 | 关 |
| L2 | 1.30 | 1.15 | 0 | 0 | 22ms |
| L3 | 1.45 | 1.30 | 1 | 1 | 关 |
| L4 | 1.60 | 1.45 | 1 | 1 | 关 |

- 输出改为 `OK level=N hook_only=1 profile=...`，面板按成功处理并记住档位；Hook 侧 3 秒 TTL 内生效，不需要重启 HAL。
- 这种模式下参数表本来就不存在，所以「关闭」只写 `state/level=0`，Hook 增强仍保留；要彻底关掉 Hook 用面板「全局增强」开关。

## 勾选系统框架后为什么会软重启（v3.2.5）

- LSPosed 的 Hook 注入在 system_server 里，改了「系统框架」作用域后，必须重启一次 system_server 才能加载；这一次软重启是 LSPosed 的正常机制，不是模块在重启手机。
- v3.2.4 及更早的开机自愈不检查模块是否登记：在没有 sqlite3 的机器（如 V2301A）上登记会静默失败，自愈每次开机都以为 Hook 丢了，最多连续软重启 4 轮，看起来就像「一勾选就重启」。
- v3.2.5 改成：
  - lsp-setup.sh 只有确认 DB 可写、APK 已装、模块行存在且启用、system 作用域存在时才写 state/lsp_registered；
  - 没有 sqlite3 / 登记失败 / 用户在 LSPosed 里手动关掉模块时，只写 state/lsp_setup_failed 或 state/lsp_disabled 并退出，不再强行打开、不再重启 zygote；
  - lsp-repair.sh 只有登记成功才自愈；只有刚登记 / 刚更新 APK 时自动跑 **1 轮**，普通开机若 Hook 缺失只记录日志、不再自动重启 zygote；手动「重载 Hook」仍是 4 轮；
  - 失败原因在 state/lsp-setup.log 与 state/lsp-repair.log。
- 正确操作：LSPosed 模块页把顶部「启用模块」打开 → 作用域只勾「系统框架」→ 按提示重启一次。之后如果 Hook 没生效，用面板「设置 → 重载 Hook（软重启）」手动重载。
- 如果仍然每次开机都软重启，把 /data/adb/haptic_boost/lsp-setup.log、lsp-repair.log 和适配报告一起发出来。

## 指纹与输入法 HEAVY（v3.2.6 / v3.2.7）

- 指纹解锁走 `com.vivo.fingerprintui` 的 `VivoEffectIDSegment`，默认白名单只含桌面/侧边栏/系统界面，所以它一直是原厂轻振（70ms，`played: null`）。
- 输入法 `com.vivo.ai.ime.nex` 打字同样走 `Composed{VivoEffectIDSegment}`，不在白名单时只有原厂短振（24–38ms，`played: null`）。
- v3.2.6 把 `com.vivo.fingerprintui` 追加进 `haptic_boost_vendor_pkgs`；v3.2.7 再自动追加当前 `default_input_method` 的包名，两者都替换成 `HEAVY_CLICK(STRONG)`。
- 白名单由 `bin/common.sh` 的 `ensure_vendor_pkgs()` 维护：开机 `service.sh` 与每次 `apply.sh` 都会检查；保留用户已有列表，只追加缺失的指纹/输入法包，不覆盖自定义。
- 实测（V2505A）：指纹事件修改前 `duration 70ms, played: Stereo{null}`，修改后 `played: Prebaked=HEAVY_CLICK(STRONG, with fallback), duration 43ms`；输入法事件修改前 `duration 24–38ms, played: null`，修改后 `duration 32–33ms, played: Prebaked=HEAVY_CLICK(STRONG, with fallback)`，trace 行 `vendor->HEAVY pkg=com.vivo.ai.ime.nex usage=18 dur=-1`。
- Hook 侧 `haptic_boost_*` 为 3 秒 TTL，改完 setting 后下一次解锁/打字即可生效，不需要重启 zygote；重启后 settings 仍在，开机脚本也会补写。

## V2546A 更强 HEAVY（v3.2.9）

- 现场报告（21:16）显示：输入法 `com.vivo.ai.ime.nex`、上滑后台 `com.vivo.upslide`、侧边栏 `com.android.systemui` 已经命中 Hook，`played` 都是 `Prebaked=HEAVY_CLICK(STRONG, with fallback)`；弱的是 HEAVY 本身的参数，不是没改写。
- 原 L2 的 predefined `effect=5` 为 `low=68 / mid=100 / high=100`，`pwl_time=0,11,27,38`，`pwl_acc=0,78,78,0`。v3.2.9 把 V2546A 的 L2/L3/L4 全部顶到 `100/100/100`，`pwl_time=0,13,32,46`，`pwl_acc=0,100,100,0`（46ms、满幅、满加速度段）；L1 保持轻量。
- 白名单新增 `com.vivo.systemuiplugin`、`com.vivo.card`、`com.vivo.globaldragdrop`；保留用户已有列表，只追加缺失项。配合原有 `com.vivo.upslide` / `com.android.systemui` / `com.bbk.launcher2` / 当前输入法，覆盖侧边栏、上滑后台、通知中心插件与拖放。
- 没有改 `num_channels/channel_mask` 去强行驱动 id=1 副马达：HAL 对双通道私有段的解析无法离线验证，先只推参数表与白名单，避免刷完不出声。
- 面板 APK 内的 `assets/haptics/v2546a/level2..4.xml` 已同步替换（仍是 4.2.0，只换资源，不动 UI/音量键补丁）。
- 生效路径：刷入后重启 → `post-fs-data.sh` 重新 bind mount 新表 → HAL 重启；Hook 白名单由 `service.sh`/`apply.sh` 写入，3 秒 TTL。

## 音量键（v3.2.8）

- 音量键按下只发一次 HEAVY_CLICK，长按不再循环连震。
- Hook 侧 `startVolKeyLoop()` 已改为空实现；单击仍走 `pulseVolKey()`，实测 dumpsys 为 `Prebaked=HEAVY_CLICK(STRONG, with fallback)`（34–46 ms）。
- 长按实测只有一条 `volkey heavy` trace，不再出现 `volkey loop start(heavy)` 与连续 pulse。
- KernelSU 下若 `/data/adb/lspd` 被标成 `system_file`，lspd 读不到模块配置；`post-fs-data.sh` 会先把该目录递归改回 `u:object_r:ksu_file:s0` 再拉起 daemon。

## LSPosed 模块几分钟后自动关闭（v3.2.11 → v3.2.12）

- 症状：刷入后 Hook 能工作几分钟，然后 LSPosed 管理器里的模块开关自己关掉，需要手动重新打开。
- 现场报告（22:05 V2301A）里 `modules` 表是：

```text
com.coldbrew.hapticboost|
com.coldbrew.hapticboost|0|1
com.coldbrew.hapticboost|system|0
```

  也就是模块行还在、`enabled=1`、`system` 作用域也在，但 **`apk_path` 被清空了**。LSPosed 刷新模块列表时会把这种行判成无效模块并自动关闭。
- 旧版 `lsp-setup.sh` 只按 `apk_path` 是否为空决定 `UPDATE` 还是 `INSERT`：路径为空时它会去 `INSERT`，撞上主键 UNIQUE 后失败，空路径永远修不回来，模块就一直被关。
- v3.2.11 修复：
  - `lsp-setup.sh` 改为按 `modules` 行是否存在决定 `UPDATE`/`INSERT`；行在但 `apk_path` 为空时直接 `UPDATE` 修复，不再触发 UNIQUE。
  - 路径为空但 `enabled=0` 时，视为坏行而不是用户主动关闭，强制恢复 `enabled=1`。
  - 新增 `bin/lsp-watch.sh`：开机后每 60 秒检查一次 `modules.apk_path`/`enabled`；空路径就地修复，`lspd` 停了只重启 daemon，不重启 zygote。
  - 用户手动关闭且路径正常时，`lsp-watch` 会写 `state/lsp_disabled` 并退出，不强行打开。
- v3.2.11 仍被反馈“几分钟内自己关”。继续排查到两个新触发点：
  1. `install-apk.sh` 原来只比文件字节数；`state/apk_size` 丢失或 `pm install` 输出不带 `Success` 时，每次开机都会重新 `pm install`。重复安装会让 LSPosed 重读模块并清空 `apk_path`，于是又回到自动关闭。v3.2.12 改为比对**已安装 APK 的 md5**，内容一致就绝不再安装；刷入时 `customize.sh` 也会写 `state/apk_md5`。
  2. `lsp-watch.sh` 原来要求 `state/lsp_registered` 存在才启动，且把“`enabled=0` + 路径非空”一律当用户手动关闭。若 LSPosed 先清路径再关开关，或 `lsp_registered` 因登记失败没写成，看守根本不会启动/会提前退出。v3.2.12 去掉该前置条件，改为每 **30 秒**检查；`enabled=0` 且 `lock=1` 时直接 `FORCE_ENABLE=1` 拉回启用，不再依赖路径是否为空。
- 默认 `haptic_boost_lock_lsp=1`（锁定启用）。这意味着在 LSPosed 管理器里手动关掉，会被看守在 30 秒内重新打开。要真正手动关闭，先执行：

```bash
su -c 'settings put global haptic_boost_lock_lsp 0'
```

  再去 LSPosed 里关；重新锁定用 `settings put global haptic_boost_lock_lsp 1`。
- `lsp-watch.sh` 每次发现 `enabled=0` 或空 `apk_path`，会先写一份现场快照 `state/lsp-disable-<时间>.log`（DB 三张表、`lspd` 进程、LSPosed/AndroidRuntime logcat 尾部），只保留最近 3 份；这样下次再自动关，报告里能直接看到当时 LSPosed 自己是怎么写的。
- 模块目录的 `bin/report.sh` 在 section 10 追加 `lsp-setup.log` / `lsp-repair.log` / `lsp-watch.log` 末尾 20 行和最新一份 `lsp-disable-*.log` 尾部 120 行；面板内置的旧报告脚本不含这几段，需要时可在 root 下直接执行模块里的 `bin/report.sh`。

## 安装

1. KernelSU 刷入模块 zip，重启。
2. 模块会：
   - 自动 `pm install` 面板 APK；
   - 自动把模块登记进 LSPosed（启用 + 作用域「系统框架」）；
   - 挂载参数表并重启 HAL。
3. LSPosed 里确认本模块已启用、作用域勾选「系统框架」。首次或更新 Hook 后如果没有生效，打开面板 → 设置 → 重载 Hook（软重启），不需要整机重启。
4. 刷入无效：面板 → 设置 → 生成适配报告 → `Download/haptic_adapt_*.txt` → 发出来。

## 卸载与清理

- KSU 管理器卸载模块会执行 `uninstall.sh`：先调 `bin/cleanup.sh --uninstall`，再删模块目录。
- `cleanup.sh` 清理范围：
  - 循环 `umount /vendor/etc/Hapticsconfig.xml`；
  - 结束 HAL 进程让其重读原生表；
  - 删 LSPosed `modules / modules_state / scope / module_configs` 行并 `wal_checkpoint(TRUNCATE)`；
  - 删除全部 `haptic_boost_*` settings 键；
  - 删除 `/data/system/haptic_boost_trace.log`、`/data/local/tmp/hb*` 临时文件；
  - 删除 `/data/adb/haptic_boost` 与 `/data/adb/modules_update/haptic_boost_v2505a`；
  - `--uninstall` 时再 `pm uninstall com.coldbrew.hapticboost`，并软重启 zygote，让已注入的 Hook 立即失效。
- 面板「设置 → 清理残留」执行同一脚本（不带 `--uninstall`，不会卸载面板）。

## 日志

- Hook：`/data/system/haptic_boost_trace.log`
- 清理：`/data/local/tmp/hb_cleanup.log`
- 模块状态：`/data/adb/haptic_boost/status.log`、`boot.log`
- 重载 Hook：`/data/adb/haptic_boost/lsp-repair.log`

## 构建

```bash
cd D:/work/HapticBoostApp
./gradlew :app:assembleRelease --no-daemon --console=plain
# 产物 app/build/outputs/apk/release/app-release.apk
```

面板工程不包含任何第三方模块管理器的业务代码，只依赖：
**Jetpack Compose + Miuix + libsu + xposed-stub**。

打包命名统一为 `iQOO 15震动增强（v3.2.12）.zip`：括号用全角，只有版本号变化。

## 变更日志

- **v3.2.12**：继续修 LSPosed 模块几分钟后自动关闭——`install-apk.sh` 改为比对已安装 APK 的 md5，内容一致绝不再 `pm install`（重复安装会触发 LSPosed 清空 `apk_path`）；`lsp-watch.sh` 去掉 `lsp_registered` 前置条件、改为 30 秒看守，`enabled=0` 且 `lock=1` 时直接 `FORCE_ENABLE=1` 拉回启用，不再把“路径非空 + enabled=0”一律当用户手动关闭；新增 `haptic_boost_lock_lsp` 开关（默认 1 锁定，设 0 才尊重手动关闭）。
- **v3.2.11**：修复 LSPosed 模块几分钟后自动关闭——现场 `modules.apk_path` 为空；`lsp-setup.sh` 改为按行存在 `UPDATE` 修复空路径（原逻辑 INSERT 撞 UNIQUE 后失败），空路径 + `enabled=0` 强制恢复；新增 `lsp-watch.sh` 每 60 秒看守空路径/停掉的 lspd，只修 DB 不重启 zygote；报告追加 LSPosed 三个日志尾部。
- **v3.2.9**：V2546A 输入法/上滑后台/侧边栏 HEAVY 顶满——predefined `effect=5` 三通道 100/100/100、`pwl_time=0,13,32,46`、`pwl_acc=0,100,100,0`；白名单补 `com.vivo.systemuiplugin` / `com.vivo.card` / `com.vivo.globaldragdrop`；面板 APK 同步替换 v2546a 三档资源。
- **v3.2.8**：音量键只保留单击 HEAVY，长按不再循环连震（二进制补丁改写 `startVolKeyLoop()` 为 return-void）；实测单击/长按各一次 HEAVY_CLICK；post-fs-data 自动修正 LSPosed 数据目录 SELinux 标签。
- **v3.2.7**：输入法按键改为 HEAVY_CLICK——`ensure_vendor_pkgs()` 读取当前 `default_input_method` 并追加其包名，实测 `com.vivo.ai.ime.nex` 从 24–38ms null 变为 32–33ms HEAVY_CLICK。
- **v3.2.6**：指纹解锁改为 HEAVY_CLICK——`com.vivo.fingerprintui` 加入 Hook 白名单默认值，新增 `ensure_vendor_pkgs()`（开机/切档自动追加，保留用户自定义），实测指纹事件从 70ms null 变为 43ms HEAVY_CLICK。
- **v3.2.5**：修复勾选 LSPosed 作用域后反复软重启——登记失败 / 无 sqlite3 / 用户手动关闭模块时不再自愈重启，自动自愈最多 1 轮；新增 state/lsp_registered、lsp_disabled、lsp_setup_failed 三个判定文件与 lsp-setup.log。
- **v3.2.4**：修复无参数表机型（V2301A / Neo8 等）切换 L1–L4 报 `NO_CONFIG`；`apply.sh` 自动降级为 Hook-only 档位并写 settings，面板显示切换成功；补充无参数表机型说明。
- **v3.2.3**：修正 V2546A 适配口径——两份报告里的 XML 实为模块挂载的 V2505A L3/L2，不是原厂表；新增首次挂载前自动备份 `state/stock.xml`、`bin/dump-stock.sh` 现场抓原厂表、报告 v4 优先输出 stock；`config/v2546a` 暂标为过渡档。
- **v3.2.1**：作者改为 DOUYXQ；简介顶部加入反馈群 1131141797；「执行」按钮改为直接打开面板，去掉切档/试震/HAL 重启，修复执行时持续震动。
- **v3.2**：主页改版，状态收进单张 hero 卡，顶栏标题不再重复；帮助卡与页脚归并；面板 4.2.0。
- **v3.1**：V2546A 参数表当时按 21406B 表重新生成，f0 兜底 136Hz；HAL 进程名兼容 `vendor.vibrator-default`；适配报告升到 v3；面板 4.1.0。该表已被 v3.2.3 证实是 V2505A L3 的挂载副本，不是原厂表。
- **v3.0**：面板重写为纯 Miuix + Jetpack Compose 独立工程（包名不变，v4.0.0），删除原模块管理器的全部页面/资源/底栏；四 Tab 模块/增强/试震/设置；卸载脚本重写，新增 `bin/cleanup.sh` 彻底清理 settings、日志、临时文件、LSPosed 注册行与更新残留；面板新增「清理残留」。
- v2.16：V2546A 口径修正为 iQOO 15 Ultra（战锤 MAX 双轴 X/Z），参数表按内核 f0 动态对齐。
- v2.13：手感只留两档（标准 22ms 轻触脉冲 / 激进统一 HEAVY），去掉轻档与双脉冲。
- v2.11：模块页新增「刷入没效果？」指引卡。
- v2.9：新桌面图标；设置页与模块页精简。
- v1.9：刷入即装面板 APK，并自动登记 LSPosed。

## 许可证

本项目采用 [MIT License](LICENSE)，版权归 © 2026 DOUYXQ 所有。

模块内的 `apk/HapticBoostLSP.apk` 为预编译面板二进制；仓库中的 shell 脚本、XML 参数表与文档均以 MIT 授权，可自由修改与再分发，保留版权声明即可。
