# Proposal

## Why

OHB 目前按「设备类型 + 方向」决定界面形态，而不是按窗口实际尺寸：PC 上窗口从 400px 拖宽到 1221px 后，首页仍渲染一列巨型卡片（已现场复现）；`WinUtils` 在 PC/2in1 上强制 `maximize()`，把窗口钉死成全屏，尺寸适配无从验证。设备形态正在融合（PC、折叠屏、平板分屏、自由窗口），只有以窗口尺寸为唯一依据才能得到正确布局。

## What Changes

- 建立**单一窗口尺寸数据源**：监听主窗口 `windowSizeChange`，把窗口宽高（vp）与断点写入 AppStorage；`Index.ets`（非 HDS 壳）与 `HdsIndex.ets`（HDS 壳）共用同一份数据，删除只有 HDS 壳才更新 `areaWidth` 的割裂实现。
- 统一断点体系：以窗口**宽度**为主（600 / 840 / 1200 vp 三级 + 超宽档），不以设备方向做任何分支判断。
- **首页**：网格列数随宽度递增（2 / 3 / 4 / 6 列），并为卡片设置最大宽度，避免宽屏上放大成巨型卡片；≥840vp 时首页启用宽屏侧边导航（分区导航从顶部横排迁移到侧边栏）。
- **视频页**：≥840vp 时切换为左右分栏——左栏为播放器 + 下方推荐视频、右栏为评论区；窄窗口保留现有的「播放器 + 推荐/评论 Tabs」堆叠形态。
- **方向策略全面尺寸驱动**：移除 PC/2in1 上的强制 `maximize()`，`DisplayHelper` 不再按设备类型选择方向；仅视频全屏播放这一场景保留横屏锁定，退出后按窗口尺寸恢复。
- 新增**调试用窗口尺寸注入**：`aa start` 的 `--ps` 参数携带目标尺寸（如 `ohbTestWindow=1400x900`）时，应用启动后调用 `mainWindow.resize()`，让任意窗口尺寸可被稳定、可重复地构造。
- 新增**窗口尺寸自动化验证**：ohosTest（Hypium + `@kit.TestKit`）用例驱动上述调试参数，按 `.id()` 断言列数/分栏节点；附一个 shell 矩阵脚本，批量采集各尺寸截图与 `dumpLayout`，作为回归证据。

## Capabilities

### New Capabilities

- `responsive-layout`: 以窗口尺寸为唯一依据的布局能力——窗口尺寸数据源与断点体系、首页网格与宽屏侧边导航、视频页宽屏左右分栏、尺寸驱动的方向策略与视频全屏例外。
- `window-layout-testing`: 窗口尺寸的自动化验证能力——调试尺寸注入入口、ohosTest 用例断言、批量尺寸矩阵采集脚本。

### Modified Capabilities

<!-- 现有 spec 只有 agent-workspace 与 build-config，均不涉及布局行为，无需求变更 -->

## Impact

- `entry/src/main/ets/pages/Index.ets`、`HdsIndex.ets`：接入统一尺寸源；首页在宽屏下切换到侧边导航形态。
- `entry/src/main/ets/viewmodel/IndexViewModel.ets`：`areaWidth`/`gridColumns()` 改为由统一断点驱动，扩充列数档位。
- `entry/src/main/ets/pages/HomePage.ets`：网格列数、卡片最大宽度、宽屏侧边导航。
- `entry/src/main/ets/pages/VideoPage.ets`：≥840vp 左右分栏布局分支。
- `entry/src/main/ets/services/appearance/WinUtils.ets`：移除 PC/2in1 强制 `maximize()`。
- `entry/src/main/ets/common/utils/DisplayHelper.ets`、`pages/VideoFullscreenPage.ets`：方向策略改为尺寸驱动，保留视频全屏横屏锁定与恢复。
- `entry/src/main/ets/EntryAbility.ets`：解析 `--ps` 调试参数，调用 `mainWindow.resize()`。
- `entry/src/ohosTest/`：新增窗口尺寸用例；新增 `scripts/` 下的尺寸矩阵采集脚本。
- `entry/src/main/module.json5`：核对 `orientation` 声明，确保不再隐含方向约束。
