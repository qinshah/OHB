# AGENTS.md

本文件为在 OHB 仓库中协作的 AI 助手与开发者提供项目背景、架构约束与工作规范。

## 项目概览

- **OHB**：基于鸿蒙原生 ArkUI 开发的第三方 Bilibili 客户端（HarmonyOS NEXT，Stage 模型，ArkTS 严格模式）。
- **目标设备**：手机 / 平板 / 折叠屏（一次开发多端适配），支持多窗口。
- **参考项目**：`PiliPlus/`（Flutter 跨平台 Bilibili 客户端）。**仅作为功能与 Bilibili API/业务流程参考，绝不照搬其架构设计与缺陷。**
- **需求文档**：`.trae/specs/harmony-bilibili-app/` 下的 `spec.md`（需求与架构原则）、`tasks.md`（实现计划与优先级）、`checklist.md`（验证清单）。

> 开始任何任务前，先阅读 spec.md 中对应功能需求（FR-*）与架构原则（AP-*），再对照 tasks.md 中的任务归属。

## 架构原则（最高优先级，贯穿所有实现）

### AP-1 分层与依赖方向

依赖必须单向：`UI/Components → ViewModel → Repository → Network/Storage`，禁止反向依赖。层次职责：

- 表现层：`pages/`、`common/components/`
- 业务层：`viewmodel/`（`@Observed`，只消费 `DataState`）
- 数据层：`data/repository/`（封装网络/缓存细节）
- 基础设施：`network/`、`services/`（storage/account）

### AP-2 网络状态模型（不沿用 PiliPlus 三态）

- `Result<T>`（`common/result/Result.ets`）：纯操作结果 `Ok<T> | Err<AppError>`，供网络/存储层返回。
- `DataState<T>`（`common/state/DataState.ets`）：UI 数据流状态机 `Idle | Loading | Refreshing | Data | Error | Empty`。
- `AppError`（`common/result/AppError.ets`）：统一错误模型，携带 `kind/code/message/retryable/cause`，禁止错误字符串散落。
- ViewModel 将 `Result` 转换为 `DataState`，UI 只感知 `DataState`。

### AP-3 播放器统一封装（内核可插拔）

- `IPlayerEngine`（`player/IPlayerEngine.ets`）：统一内核接口（play/pause/seek/音量/倍速/状态流等）。
- 默认实现 `AvPlayerEngine`（基于 `@ohos.multimedia.avplayer`）；预留 mpv/mdk 接入点。
- `PlayerController`：统一控制器，持有 Engine，向上暴露状态流。
- **系统音量**：禁止直接调 `AudioVolumeGroupManager.setVolume`；由 UI 层隐藏的 `AVVolumePanel` 组件驱动，`SystemAudioHelper` 仅监听实际音量并回写。

### AP-4 持久化与设置导入导出

- 每个设置项独立 key（`PrefsStorage`），修改只写对应 key，不整体重写。
- 默认值集中维护（规划中 `SettingDefaults`）。
- 导出仅含值 ≠ 默认值的项 + `schemaVersion`；导入时缺失 key 重置为默认值。
- 凭证等敏感数据不进入设置导出。

### AP-5 多用户与认证

- `AccountManager`：多账户列表 + 当前激活账户，切换时切换 Cookie 与用户级设置命名空间。
- 凭证使用 `SecureStorage`（系统 Asset Store 加密托管），不落明文。
- 扫码登录优先（TV 端 `passport-tv-login` 流程）。

### AP-6 多设备适配

- 基于 `Navigation`/`NavDestination`（单栏/分栏自动切换），使用栅格与断点（`AppTheme.ets` 中 `Breakpoints`/`gridColumns`）。
- 尺寸使用 fp/vp 资源限定，支持深色模式与动态取色（`AppColors.refresh()` 按主题解析）。
- 沉浸光感通过 HDS 组件 `barFloatingStyle.systemMaterialEffect` 实现，兼容回退见 `ImmersiveHelper`（详见「编码规范」）。

### AP-7 弹幕

- 首选 `@ohos/danmakuflamemaster`，备选 `@esky/barrage` 或自绘 Canvas；弹幕层与播放器解耦，订阅播放器时间轴。

### AP-8 测试与质量优先级

- V1 首要目标：**编译无报错、应用可运行、核心流程可用**（登录/首页/搜索/动态/视频播放）。
- 单元测试为低优先级（Hypium），可后续补充，聚焦网络层、WBI 签名、`Result`/`DataState`、持久化导入导出、播放器状态机等纯逻辑。

## 目录结构

主工程位于 `entry/`：

```
entry/src/main/ets/
├── common/          # 通用：components / constants / navigation / result / state / utils
├── data/repository/ # Repository（Auth/Video/Search/Dynamic）
├── models/          # 数据模型（ArkTS class/interface + JSON 反序列化）
├── network/         # HttpClient / BiliApi / WbiSigner / AppSigner / CookieManager / ApiConstants
├── pages/           # 页面与路由（Index 主框架壳 + NavDestination 子页）
├── player/          # IPlayerEngine / AvPlayerEngine / PlayerController / PlayerTypes
├── services/        # account（AccountManager）、storage（PrefsStorage/SecureStorage）
├── theme/           # AppTheme（品牌色/断点/栅格）
└── viewmodel/       # @Observed ViewModel，消费 DataState
```

其他：

- `PiliPlus/`：Flutter 参考项目，只读参考，不要修改。
- `.trae/specs/harmony-bilibili-app/`：需求/任务/清单，任务完成后同步勾选 checklist.md。
- 测试：`entry/src/test/`（本地单测）、`entry/src/ohosTest/`（仪器测试），基于 `@ohos/hypium`。

## 技术栈与构建

- 语言/框架：ArkTS 严格模式 + ArkUI 声明式 + HarmonyOS NEXT Stage 模型。
- SDK：API 14+（compatibleSdkVersion=14）；当前构建使用 API 26（`compileSdkVersion/targetSdkVersion = "26.0.0"`，字符串格式），`runtimeOS: "HarmonyOS"`（HarmonyOS SDK 可用 HDS 组件）。
- 若切换回 OpenHarmony SDK（见 `build-profile.json5.example` 模板），`@kit.UIDesignKit`（HDS）将不可用，沉浸光感应改用 `@kit.ArkUI` 的 `uiMaterial`/`barFloatingStyle.systemMaterial` 方案，并相应调整 `runtimeOS`。
- 构建命令（项目根目录暂无 hvigorw 脚本，使用 DevEco 自带）：

```bash
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --no-daemon -p buildMode=debug
```

- `local.properties` 中的 `sdk.dir` 指向本机 OpenHarmony SDK（不入库）。
- 验证标准：全量编译 **0 报错**；改动涉及 UI 时确保深/浅色、手机/平板形态均正常。

## 编码规范

### ArkTS 严格模式

- 全程使用静态类型；避免 `any`；接口/类字段显式声明类型。
- 注释使用中文，标识符（类名/方法名/变量名）使用英文。
- 网络层返回 `Result<T>`，ViewModel 暴露 `DataState<T>` 状态流；UI 通过 `@State vm` / `@Observed` 绑定。

### 本项目实测踩坑（必须遵守）

- interface 内联对象类型（`a?: { b?: string }`）会报编译错误 10605040，必须拆成独立 interface。
- 空对象字面量 `?? {}` 报 10605038，需用显式占位类（如 `new EmptyData()`）。
- `getHostContext()` 返回可空，使用前必须判空。
- `$r()` 资源引用在普通类的静态字段中运行期会解析失败（白屏），默认用内联十六进制色值，主题色通过 `AppColors.refresh()` 运行时解析。
- `@State` 属性名不得与 `CustomComponent` 基类属性冲突（如 `tabIndex/width/opacity`）。
- `Column` 无 `alignContent`，用 `height(100%)` + `justifyContent(FlexAlign.End)` 等实现。
- AVPlayer：`setSpeed` 只接受 `PlaybackSpeed` 枚举档位；`bufferingUpdate` 回调签名是 `(infoType, value)`。
- 沉浸光感：当前基于 HarmonyOS SDK，使用 HDS 组件（`@kit.UIDesignKit` 的 `HdsNavigation`/`HdsTabs`/`hdsMaterial`），通过 `barFloatingStyle.systemMaterialEffect` 配置 ADAPTIVE 材质；兼容检测用 `deviceInfo.sdkApiVersion >= 23`（`ImmersiveHelper`），不支持时回退为普通 `Navigation + Tabs` + 不透明背景。OpenHarmony SDK 下 HDS 不可用，需回退 `uiMaterial`/`systemMaterial`（since 26.0.0）方案。
- build-profile 中 API 26+ 版本号必须用字符串（`"26.0.0"`），API 10-25 用数字；`compatibleSdkVersion` 保持数字 14。

### 路由与页面

- 主框架 `pages/Index.ets`：`Navigation`（NavPathStack）+ Tabs（首页/搜索/动态/我的），路由名集中在 `RouteNames.ets`。
- 二级页面用 `NavDestination` 注册在 `Index.ets` 的 `pageMap` 中。
- 路由跳转统一走 `NavService`（NavPathStack 不能做状态装饰，直接持有会触发 changed-during-render 白屏）。

## 工作流程

1. 先在 `.trae/specs/harmony-bilibili-app/tasks.md` 中确认任务与优先级（P0 V1 达标 → P1 架构达标 → P2 功能完善 → P3 质量打磨）。
2. 按 AP 原则实现，遵循依赖方向；新模块参考已有同层文件的结构与命名。
3. 完成功能后跑全量构建，确认 0 报错；涉及 UI 的改动验证深/浅色与多形态布局。
4. 同步更新 `.trae/specs/harmony-bilibili-app/checklist.md`（勾选对应 Checkpoint），并保持 tasks.md 任务状态准确。
5. 新增的 B 站接口参数/流程若参考自 PiliPlus，记录在代码注释中（仅引用 API 行为，不复制其架构）。

## Git 规范

- 提交信息使用 Conventional Commits + 中文描述：`feat(ui): 实现...`、`fix(auth): 修复...`、`refactor(player): ...`、`style(...)`、`chore(config): ...`、`docs(specs): ...`。
- 新分支使用 `codex/` 前缀。
- `build-profile.json5`、`local.properties`、`oh_modules/`、`build/` 等不入库。
