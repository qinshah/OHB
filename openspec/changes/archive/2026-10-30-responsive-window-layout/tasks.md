# Tasks

## 1. 统一窗口尺寸源与断点

- [x] 1.1 在 `WinUtil` 中注册 `mainWindow.on('windowSizeChange')`，用 `px2vp` 换算后写入 AppStorage 的 `winWidthVp` / `winHeightVp`，保留 `avoidAreaChange` 既有逻辑；验证：真机调整窗口尺寸后 hilog 打印新宽高，且 AppStorage 值与 `hidumper -s WindowManagerService -a '-w <id>'` 的 WindowRect 换算结果一致
  - 证据：`windowSize变化：1412x966px -> 1129.6x772.8vp`（密度 1.25），与 hidumper 的 `ohb0 [0 0 1412 966]` 一致
- [x] 1.2 新增 `common/window/WindowLayout.ets`（`SizeClass`、`sizeClassOf()`、`gridColumns()`、`isWide()`、`CARD_MAX_WIDTH`、`CARD_GAP`），页面不再自维护阈值；验证：`grep -rn "\b(840|1200|600)\b"` 在页面与 viewmodel 中无布局阈值字面量，首页在 400 / 700 / 900 / 1300 / 1600px 宽下分别得到 2 / 2 / 3 / 4 / 6 列
  - 证据：仅剩 `AvPlayerEngine` 的 600ms 同步容差与 `PlayerControlView` 的手势分母初值（非布局断点）；矩阵实测列数 2/2/3/4/6
- [x] 1.3 删除 `IndexViewModel.areaWidth` 与 `HdsIndex` 的 `onAreaChange`，两套入口壳改用同一份 AppStorage 尺寸；验证：入口壳不再持有尺寸状态，布局判定只发生在 `HomePage` / `VideoPage`
  - 结构证据：`grep -n "areaWidth\|onAreaChange\|winWidthVp" pages/Index.ets pages/HdsIndex.ets` 无命中——两套壳都不读窗口尺寸，尺寸只经 AppStorage 被 `HomePage` / `VideoPage` 消费，因此不存在"某一套壳漏改"的分支；
  - 备注：`EntryAbility.pickShell()` 新增调试参数 `--ps ohbShell index|hds` 用于强制选壳；本台开鸿 PC `hds=false`，矩阵跑的是 `pages/Index`；`HdsIndex` 的运行时表现需在有 HDS 的真机鸿蒙上随 7.2 一并回归

## 2. 首页响应式布局

- [x] 2.1 首页视频流按断点设置 `lanes`，并给 `List` 加居中 + `maxWidth` 上限让单卡不超过 `CARD_MAX_WIDTH`，为 `List` 加 `.id('home_feed')`；验证：1600px 宽窗口截图里单行 6 张，`dumpLayout` 中 `home_feed` 首行子节点数为 6，卡片渲染宽度 ≤ 240vp
  - 证据（卡片内容层实测）：400px→148.8vp / 900px→229.6vp / 1300px→226.4vp / 1600px→188.0vp / 1920px→229.6vp，全部 ≤ 240
- [x] 2.2 首页在 ≥840vp 时启用侧边导航（宽度 96vp，纵向分区项），顶部横向分区栏改为不可见但组件实例保留（`Visibility.None`，不出现在无障碍树中），侧边栏与顶栏共用 `switchTab` 懒加载；验证：窗口在 700px ↔ 1400px 之间来回拖拽调整，选中分区不丢失，`FeedTab` 不重新请求首屏（hilog `feed loadFirst` 计数不变）
  - 证据：`scripts/window-live-toggle.sh` 通过 —— 清 hilog 缓冲后 `feed loadFirst` 计数宽→窄→宽恒为 0/0/0（不重复请求首屏），首卡标题三步一致（选中分区不丢）
- [x] 2.3 为侧边栏、顶部分区栏加 `.id('home_side_rail')` / `.id('home_partition_bar')`；验证：`dumpLayout` 在 1400px 时 `home_side_rail` 可见且宽度非 0、`home_partition_bar` 不出现，在 700px 时相反

## 3. 视频页宽屏分栏

- [x] 3.1 视频页在 ≥840vp 时切换为左右分栏：左栏播放器（16:9）+ 下方多列推荐，右栏详情（限高 45% 可滚）+ 评论独立滚动；<840vp 保持现有堆叠 Tabs；验证：1600px 宽窗口下推荐与评论同时可见，900px 下回到 Tabs 形态，播放不中断
  - 证据：1600x900 → player [0,46,1075,651] / related [0,651,1075,966] / comments [1085,46,1612,966]；900x900 → 仅 video_player
- [x] 3.2 分栏形态下评论只加载一次、切换形态不重复请求；验证：窄→宽切换后 hilog `comment loadOnce` 计数 +1 且不再增加
  - 证据：toggle 脚本清缓冲后，窄窗计数 0 → 切宽后 1（同一页面仅加载一次）
- [x] 3.3 为播放器、推荐列表、评论面板加 `.id('video_player')` / `.id('video_related')` / `.id('video_comments')`；验证：`dumpLayout` 在 1300px / 1600px 时三者同时存在，且 `video_related` 与 `video_comments` 的 x 区间不重叠、推荐区在播放器下方
- [x] 3.4 窄↔宽实时切换不丢播放进度；验证：拖宽窗口前后播放器时间文本单调不减
  - 证据：00:08（窄）→ 00:17 / 00:18（宽），未回到 00:00

## 4. 方向与窗口策略

- [x] 4.1 删除 `WinUtil` 的 `maximize()` 与 desktop 分支，统一 `setWindowLayoutFullScreen(true)`，并在 `Index.ets` 补上 `bottomRectHeight` 底部内边距；验证：应用不再主动最大化（全仓无 `maximize()` 调用），冷启动窗口尺寸交由系统决定（本 PC 为 1920x1080），底部导航不被 Dock 遮挡
- [x] 4.2 清理 `DisplayHelper` 与 `VideoFullscreenPage` 的设备/折叠态方向分支：非全屏页只恢复 `UNSPECIFIED`，视频全屏仅在宽高比 > 1.2 时锁横屏，竖屏视频不锁方向；退出视频发起的全屏时 `recover()` 还原浮窗尺寸；验证：PC 上进入视频全屏（1920x1080）再退出，WindowRect 回到进入前的 1412x966
- [x] 4.3 核对 `module.json5` 的 `orientation` 不隐含方向限制，并确认全仓无其它按设备类型做布局判断的代码；验证：`grep -rn "deviceType|isFoldable|getFoldStatus"` 仅剩 `WinUtil` 的一行日志；`orientation: auto_rotation_unspecified`

## 5. 调试窗口尺寸注入

- [x] 5.1 新增 `WindowTestHook`：解析 `want.parameters['ohbTestWindow']`（`WxH`，px），在 `loadContent` 回调中调用 `recover()` + `resize()`（首帧必失败，400ms 后重试一次），仅 `BuildProfile.DEBUG` 生效；在 `EntryAbility` 接入；验证：`aa start -a EntryAbility -b com.dev4harmony.ohb --ps ohbTestWindow 1400x900` 后 `hidumper` 的 WindowRect = 请求尺寸 + 装饰边（1412x966），首页列数为该宽度对应值
- [x] 5.2 校验异常参数不影响启动；验证：`--ps ohbTestWindow 3000x900` 与 `--ps ohbTestWindow abc` 均能正常启动，hilog 含拒绝原因（`非法或超出范围 [320, 1920]，忽略`），窗口保持系统默认尺寸
- [x] 5.3 验证发布构建忽略调试参数；验证：`devecocli build --build-mode release` 生成的 `BuildProfile.ets` 里 `DEBUG = false`，安装该包后 `--ps ohbTestWindow 1400x900` 启动，WindowRect 仍为 1920x1080 且 hilog 无新增 `WindowTestHook` 记录

## 6. 自动化测试与采集脚本

- [x] 6.1 ohosTest 覆盖断点与列数判定逻辑：`entry/src/ohosTest/ets/test/WindowLayout.test.ets` 断言 599.9/600/839.9/840/1199.9/1200 边界、`isWide`、列数映射 2/3/4/6、`gridMaxWidth` 单卡不超上限；验证：`devecocli build --modules entry@ohosTest` + `aa test` 5 个用例全部通过
  - 备注：UI 层面的列数/分栏断言由 6.3 的矩阵脚本承担——测试进程无法 force-stop 并带参数重启被测应用
- [x] 6.2 分栏与列数的 UI 断言只依赖稳定 id 与 bounds，不依赖文案，语言切换不影响结论；验证：矩阵脚本在中文系统下 5 档全绿
  - 备注：英文环境复跑待有 HDS 真机时随 7.2 一起做
- [x] 6.3 新增 `scripts/window-matrix.sh`（+ `scripts/window_layout_check.py`）：视频页断言含「起播门禁」——轮询布局树直到播放器报出非零总时长（取流快慢不定，固定 sleep 会误报 00:00/00:00）：按尺寸表逐个启动、等待稳定、采集 `devecocli ui screenshot`、`devecocli ui layout --format json`、`hidumper` 的 WindowRect，逐档断言列数与分栏，输出到 `out/window-matrix/<WxH>/`（7 个文件/档）；连接异常时 `hdc kill && hdc start && hdc tconn` 重连并重试一次；验证：连续执行两次均生成完整目录且 `failures.txt` 为空，脚本头部含用法说明
- [x] 6.4 拖拽兜底通道：实测宽度偏差超过 `--tolerance` 时改用 `devecocli ui drag` 拖窗口右边缘，按实测宽度闭环修正（该 WM 位移 <60px 不响应，故精度下限 60px），仍不达标即判该尺寸失败；验证：`--no-inject` / `--decoration -400` 两种注入不可用的模拟场景下，脚本日志显示逐轮收敛后才继续断言

## 7. 整体回归

- [x] 7.1 在 PC（192.168.43.11:10178）上执行完整尺寸矩阵（400/700/900/1300/1600 宽，另加系统最大化那一档 `--no-inject -s 1920x1080 --decoration 0 --tolerance 0`），逐张核对截图：窄窗 2 列 + 顶部导航、中等 3/4 列、宽窗 6 列 + 侧边导航、视频页宽窗左右分栏；验证：`out/window-matrix/` 下每尺寸截图与 `dumpLayout` 成对存在，失败汇总为空
- [x] 7.2 在手机上做一次回归：竖屏首页、视频页、视频全屏进出、底部导航与安全区无回归，并覆盖 `HdsIndex` 入口壳与英文语言环境；验证：真机截图正常，hilog 无异常报错
  - 手机侧结论：用户已在手机上实测，无回归（2026-10-30 用户确认），本项按此关闭
  - 自动化侧记录（保留备查）：① 唯一连接的设备是这台开鸿 PC，`hds=false`，强制 `--ps ohbShell hds` 会因缺 `@kit.UIDesignKit` 闪退；② 本机有 HarmonyOS 7.0.0(26.0.0) 的 `Huawei_TripleFold` 模拟器实例（展开态 3184x2232px，理论上是理想的 HDS 宽窗目标），但冷启动失败——`~/.Huawei/Emulator/deployed/Huawei_TripleFold/Log/Emulator.log` 报 `No enough space to start Emulator`，宿主数据盘 98% 满（剩 ~10Gi），进程跑了 17 分钟始终未注册到 hdc；`devecocli emulator stop` 报成功但进程未退出，最后用 SIGTERM 收掉（现两实例均 stopped）
  - 解除条件：清出足够磁盘空间后 `devecocli emulator start "Huawei_TripleFold"` 即可跑 `scripts/window-matrix.sh -d <emulator serial>`（含 `ui layout` 断言与英文环境复跑），或接入一台 HDS 真机

## Workflow follow-up

- 待用户确认后推送分支并触发 CI 构建。
- 发版前在真实 PC 与手机各跑一遍第 7 组回归（手机侧含 `--ps ohbShell hds` 与英文环境）。
