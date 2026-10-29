# Design

## Context

动机见 `proposal.md`，行为契约见 `specs/responsive-layout/spec.md` 与 `specs/window-layout-testing/spec.md`。当前实现的关键事实：

- 入口壳有两套：`EntryAbility` 按 `ImmersiveHelper.isHdsSupported` 加载 `pages/HdsIndex` 或 `pages/Index`（`entry/src/main/ets/entryability/EntryAbility.ets:37`）。
- 只有 `HdsIndex` 通过 `onAreaChange` 把宽度写进 `IndexViewModel.areaWidth`（`entry/src/main/ets/pages/HdsIndex.ets:120`）；`Index.ets` 从不写入，`areaWidth` 永远是初值 360 → `gridColumns()` 恒为 2，这就是「宽窗口仍是一列大卡片」的直接原因（另一层原因是 `IndexViewModel` 是 `@Provide` 的普通 `@Observed` 对象，`lanes()` 读到的是跨对象属性，变更传播不可靠）。
- `WinUtil` 在 desktop 上直接 `mainWindow.maximize()`（`entry/src/main/ets/services/appearance/WinUtils.ets:36`），窗口无法被外部改尺寸。
- `DisplayHelper` 依据设备类型/折叠态决定方向（`entry/src/main/ets/common/utils/DisplayHelper.ets:74-88`），并在非全屏页 `exitAppFullscreen()` 中恢复 `UNSPECIFIED`。
- `VideoPage` 是 `Column { Stack(播放器, aspectRatio 16:9); Tabs(推荐/评论) }`（`entry/src/main/ets/pages/VideoPage.ets:93-193`）；播放器节点与全屏页共享 `VideoNodeController`，容器重建由既有 `containerSeq + makeNode` 路径兜底。
- `HomePage` 是 `Column { 搜索排; 横向分区栏; Tabs(5 个分区) }`，内容为 `FeedTab`（`List.lanes(gridColumns())`）。
- 测试骨架 `entry/src/ohosTest` 已存在（Hypium 模板），尚无窗口尺寸相关用例。

## Goals / Non-Goals

**Goals:**

- 一处监听、全局共享的窗口尺寸数据源，两套入口壳行为一致。
- 布局形态只由窗口宽度断点决定，断点与列数的映射集中定义、可单测。
- 首页与视频页在宽窗口下给出符合宽度的形态，且切换时不丢选中分区、不中断播放。
- PC 上窗口可被外部/测试调整，尺寸矩阵可自动化采集与断言。

**Non-Goals:**

- 不为窄窗口重做视觉稿，不改变现有配色、图标、文案规范。
- 不引入 `GridRow`/`GridCol` 重写列表；继续使用 `List` 的分道（lanes）以保留懒加载。
- 不做平板/折叠屏专属的新形态（折叠态不再参与布局判断）。
- 不引入 Python Hypium / DevEco Testing 的独立工程，测试全部落在现有 ohosTest + 脚本。

## Decisions

### 1. 单一尺寸源放在 `WinUtil`，写入 AppStorage

在 `WinUtil` 构造时（`getMainWindowSync()` 之后）注册 `mainWindow.on('windowSizeChange')`，用 `mainWindow.getUIContext().px2vp` 换算宽高，写入 AppStorage 的 `winWidthVp` / `winHeightVp`，并据此写入 `windowSizeClass`。删除 `HdsIndex` 的 `onAreaChange` 与 `IndexViewModel.areaWidth`。

- 备选：每页各自 `onAreaChange` —— 各页时序不同、HDS 与非 HDS 已出现事实上的不一致，弃用。
- 备选：`display.on('change')` —— 反映物理屏幕而非窗口，自由窗口/分屏下错误，弃用。
- 备选：`WindowMetrics` 独立单例 —— 与 `WinUtil` 都要拿 `mainWindow`，多一处初始化时序，不如并入。

### 2. 断点与列数集中在一处纯函数模块

新增 `entry/src/main/ets/common/window/WindowLayout.ets`：导出 `SizeClass`（sm/md/lg/xl）、`sizeClassOf(widthVp)`、`gridColumns(widthVp)`、`isWide(widthVp)`（≥840vp）、`CARD_MAX_WIDTH`、`CARD_GAP` 等常量。页面只读断点结果，不再各自写字面量 600/840/1200。

- `IndexViewModel.gridColumns()` 保留为对 `gridColumns(this.widthVp)` 的薄封装或直接删除，避免第二份阈值。
- 页面用 `@StorageProp('winWidthVp') winWidthVp: number` 直接读取，而不是通过 `@Provide` 的 `@Observed` 对象间接读取。这是修复「`lanes()` 不重算」的关键：`@StorageProp` 变更会驱动宿主组件刷新，`lanes()` 随之重新求值。

### 3. 首页：零结构变化地切换顶部/侧边导航

`HomePage` 的骨架固定为：

```
Flex(direction 恒为 Row) {
  侧边导航（宽度：宽屏 96vp，窄屏 0vp；visibility 同步切换）
  Column { 搜索排; 顶部横向分区栏（宽屏 visibility None）; Tabs(分区) }.layoutWeight(1)
}
```

侧边栏与顶栏**始终参与组件树**，只改宽度与可见性，保证 `Tabs` 及其 `TabContent` 的结构地址不变 —— 否则每次跨越 840vp 都会重建 `FeedTab`，丢失已加载数据与滚动位置。侧边栏点击通过 `TabsController.changeIndex()` 切换分区，`Tabs.onChange` 反向同步 `currentTab`，两者共用 `switchTab` 的懒加载逻辑。

网格：`List.lanes(gridColumns(winWidthVp))`；为满足卡片最大宽度，`List` 外包一层居中容器，`List` 自身 `constraintSize({ maxWidth: gridColumns * (CARD_MAX_WIDTH + CARD_GAP) })`，超出部分成为页面左右留白。

- 备选：`List.lanes({minLength, maxLength})` 自适应列数 —— 列数由引擎推断，无法保证规格里的 2/3/4/6 档位，弃用。
- 备选：`GridRow` 栅格 —— 需要改写懒加载列表，成本高，弃用。

### 4. 视频页：宽屏左右分栏，播放器子树保持稳定

≥840vp 时：

```
Row {
  Column { 播放器 Stack(16:9); 推荐列表(多列网格, layoutWeight 1) }.layoutWeight(2)
  评论面板(独立滚动, 宽 32%~40%, 320~420vp 夹取).layoutWeight(1)
}
```

<840vp 时保持现有 `Column { 播放器; Tabs(推荐/评论) }`。两种形态共用一个渲染入口：

- 播放器 `Stack`（含 `NodeContainer`、弹幕层、控制层）在两种形态下都位于 `Flex/Row` 左侧 `Column` 的第一个子节点，结构地址不变，避免重建 `NodeContainer`；跨形态切换若仍触发 `containerSeq` 重建，由既有 `makeNode` 重挂载路径兜底，需真机确认画面不中断。
- 评论面板与「Tabs 里的评论页」共用同一个 `CommentTab` builder；评论数据保持在页面级 `commentVm`，形态切换导致节点重建时不会重复拉取。
- 宽屏下推荐列表默认加载（无需切 tab），评论默认加载一次；窄屏维持现有「切到评论 tab 才加载」。

### 5. 方向与窗口：删除设备类型分支，保留视频全屏例外

- `WinUtil` 删除 `maximize()` 与 `isDesktop()` 分支，所有设备统一 `setWindowLayoutFullScreen(true)`；桌面 Dock 遮挡问题改由 `bottomRectHeight`（既有 `avoidAreaChange`）作为底部内边距解决，`Index.ets` 补上与 `HdsIndex` 一致的底部安全区处理。
- `DisplayHelper` 删除 `isExpandedOrHalfFolded()` 与 `setPortrait()` 分支：非全屏页只调用 `setPreferredOrientation(UNSPECIFIED)`；视频全屏且宽高比 > 1.2 时锁 `AUTO_ROTATION_LANDSCAPE`，其余情况不锁方向（PC 上竖屏视频不再把窗口锁成竖条）。
- `module.json5` 的 `orientation` 保持不限制方向的取值，不再作为布局依据。
- `VideoFullscreenPage` 删除 `display.on('foldStatusChange')`（折叠时自动退出全屏）：折叠态不再是决策输入，折叠只表现为窗口尺寸变化。代价是折叠屏设备上"合上盖子还在全屏"不再自动回详情页，由全屏页自适应窄窗口承担。
- 横向视频判定从散落的 `> 1.2` 抽成 `WindowLayout.isLandscapeVideo(aspect)`，`applyFullscreenForVideo` 打印 `fullscreen aspect=… lockLandscape=…`，让"仅横屏视频锁横向"在设备上可核对。
- 视频发起的全屏会把 PC 窗口切成最大化，退出时 `DisplayHelper.exitAppFullscreen()` 先 `recover()` 再恢复系统栏，把窗口还原成进入前的浮窗尺寸（实测 1920x1080 → 1412x966）。该动作只在 `applyFullscreenForVideo()` 置位后执行一次，避免导航到普通页面时误把用户的全屏窗口缩小。

### 6. 调试尺寸注入：`--ps` 参数 + DEBUG 构建门禁

`EntryAbility.onWindowStageCreate` 的 `loadContent` 回调里调用新增的 `WindowTestHook.apply(want, windowStage)`：

- 读取 `want.parameters['ohbTestWindow']`（形如 `1400x900`，单位 px），解析失败或越界（宽 < 320 或 > 1920，高 < 320 或 > 1920）时只打 error 日志并正常启动。
- 仅在 `BuildProfile.DEBUG === true` 时生效；release 构建直接返回，满足「发布构建忽略该参数」。
- 在 `loadContent` 回调之后再 `resize`（此时才拿得到 UIContext，`WinUtil.init` 也在同一回调里），避免窗口在首帧前改变尺寸导致布局闪动；resize 后 `windowSizeChange` 会把新尺寸推给 AppStorage，后续流程与用户手动拖拽完全一致。
- `resize` 前必须先 `recover()`：窗口若沿用上次的全屏/最大化态，`resize` 会以 `This window state is abnormal` 被拒；且首帧那次调用仍会被拒，需要延后 400ms 重试一次才稳定成功。
- `EntryAbility.pickShell()` 另加调试参数 `--ps ohbShell index|hds`（同样 DEBUG 门禁），用于在同一台设备上强制选入口壳。本台开鸿 PC `hds=false`，默认即 `pages/Index`；`HdsIndex` 需换有 HDS 的真机鸿蒙回归。

### 7. 测试：ohosTest 负责断言，shell 脚本负责矩阵留证

- 关键节点补 `.id()`：`home_feed`（List）、`home_side_rail`、`home_partition_bar`、`video_player`、`video_related`、`video_comments`。
- 分工按「谁能启动被测应用」划定：ohosTest 用例只覆盖断点与列数映射的纯逻辑（`WindowLayout.test.ets`，含 600/840/1200 边界与 `gridMaxWidth` 上限）；UI 尺寸断言放在采集脚本里，因为测试进程无法带参数 force-stop 并重启被测应用。
- 列数由解析 `home_feed` 直接子节点坐标、按首个 y 行归组计数得到；分栏断言检查 `video_related` 与 `video_comments` 同时存在且 x 区间不重叠、推荐区位于播放器之下。断言只依赖 id 与几何关系，不依赖文案，因此与系统语言无关。
- `scripts/window-matrix.sh`（+ `scripts/window_layout_check.py` 做几何断言）：逐项启动 → 轮询布局树稳定 → `devecocli ui screenshot` + `devecocli ui layout --format json` + `hidumper` 取 WindowRect → 落盘到 `out/window-matrix/<WxH>/`（每档 7 个文件）；连接异常先 `hdc kill; hdc start; hdc tconn <ip:port>` 重连并重试一次并记入 `reconnects.txt`，最终把失败项写进 `failures.txt` 并以非零码退出。
- 期望宽度 = 请求的内容宽度 + 装饰边（`--decoration`，该 PC 为 12px），断言一律用实测 rect。
- `scripts/window-live-toggle.sh` 补实时切换场景：拖边缘改尺寸（不重启）后断言选中分区、`feed loadFirst` 计数、`comment loadOnce` 计数与播放器时间文本，覆盖 resize 注入无法验证的状态保持。
- 兜底：`devecocli ui drag` 拖窗口右边缘 —— 依赖边框命中，位移 <60px 不响应且行程有百分之几的缩放误差，因此按实测宽度闭环修正、精度下限 60px，达下限后按实测宽度继续断言；最大化态窗口没有边缘热区，此时直接判该尺寸失败。resize 注入可用时不走这条通道。

## Risks / Trade-offs

- [列数/形态切换时列表重建、滚动位置丢失] → 保持 `Tabs`/`TabContent` 结构地址稳定；列数变化只影响 `lanes()`，不重建 `FeedTab`；测试等待布局稳定后再断言。
- [分栏切换导致 `NodeContainer` 重建、画面闪断] → 共用稳定播放器子树 + 既有 `makeNode` 重挂载路径；真机上逐尺寸验证，若中断则退回 `Flex.direction` 方案（同一子树改排列方向）。
- [移除 `maximize()` 后 PC 底部导航被 Dock 遮挡] → 依赖 `avoidAreaChange` 的 `bottomRectHeight` 内边距，并在 PC 上回归首页/动态/我的三页。
- [窗口尺寸参数被外部滥用改变窗口] → 仅 `BuildProfile.DEBUG` 构建生效，release 直接忽略并记日志；解析失败不影响启动。
- [测试断言依赖 `dumpLayout` 几何解析，版本间字段可能变化] → 断言只依赖 `id` 与 bounds 坐标，不依赖层级序号；解析失败时输出原始树到测试报告便于定位。
- [卡片最大宽度在超宽屏让内容偏窄] → 上层容器居中呈现，留白对称；具体数值先取保守值，按真机观感调整（不影响规格）。

## Migration Plan

无数据迁移。改动按「尺寸源 → 断点/首页 → 视频页 → 方向与窗口 → 调试入口 → 测试」顺序提交，每一步都可在真机单独回归；回滚即回退对应提交，规格与实现无持久化状态耦合。

## Open Questions

- ~~`CARD_MAX_WIDTH` 取值~~ 已定：240vp（6 列时实测卡片槽宽 196.8vp、渲染宽 ≤ 240vp）。
- 宽屏右栏「详情 + 评论」的比例目前取 1/3 窗宽 + 详情限高 45%，观感是否需再调待真机鸿蒙与更多 PC 分辨率下复核。
- `HdsIndex` 入口壳与英文语言环境的矩阵复跑仍为空白（本台 PC 无 HDS 能力），见 tasks 7.2。
