# 鸿蒙 Bilibili 第三方应用 (OHB) - 产品需求文档

## 概述
- **摘要**: 基于鸿蒙原生 ArkUI 框架开发的第三方 Bilibili 客户端 (OHB)。功能实现以 PiliPlus 为参考基准，但**项目基础架构必须按照鸿蒙及行业标准的应用开发最佳实践独立搭建，不照搬 PiliPlus 的设计与缺陷**。覆盖视频播放、弹幕互动、用户账户管理、直播观看、内容推荐、搜索、动态、收藏、消息等核心模块。
- **目的**: 为鸿蒙用户提供原生体验的 Bilibili 应用，架构清晰、内核可插拔、设置可迁移、一次开发适配多设备形态。
- **目标用户**: HarmonyOS NEXT 手机、平板、折叠屏等设备的 Bilibili 内容消费用户。

## 架构原则（最高优先级，贯穿全项目）

> 以下原则优先于任何功能需求，所有任务实现都必须遵守。

### AP-1: 基础架构遵循鸿蒙/行业最佳实践
- **不照搬 PiliPlus**：PiliPlus 仅作为功能实现参考（API 调用、参数、业务流程），其架构设计（如 LoadingState 三态、目录结构、状态管理方式）不直接迁移。
- **分层架构**：表现层 (UI/Components) → 业务层 (ViewModel/UseCase) → 数据层 (Repository → DataSource/Network/Storage)，职责单一。
- **依赖方向单一**：UI → ViewModel → Repository → Network/Storage，禁止反向依赖。
- **ArkTS 严格模式**：使用静态类型、Sendable 并发对象，遵循官方 ArkTS 适配规范。

### AP-2: 网络层状态设计（不沿用 PiliPlus 三态）
- **请求结果与 UI 状态分离**：
  - `Result<T, E>`：纯操作结果，`Ok<T>` | `Err<E>`，关注错误细节（业务码、错误类型、可重试性）。
  - `DataState<T>`：UI 数据流状态机 = `Idle | Loading | Refreshing<T> | Data<T> | Error | Empty`，比三态更完整，覆盖首屏/刷新/分页/空/错等场景。
- **统一错误模型**：`AppError` 携带 code、message、retryable、原始异常，避免字符串散落。
- **Repository 模式**：网络/缓存/数据库细节封装在 Repository，ViewModel 只消费 `Flow<DataState<T>>`（鸿蒙用 AppStorage/EmitterAPI 或自封装响应式流模拟）。

### AP-3: 视频播放器统一封装（内核可切换）
- **抽象层 `IPlayerEngine`**：定义播放/暂停/seek/音量/亮度/倍速/清晰度/截图/释放 等能力接口，与具体实现解耦。
- **默认实现 `AvPlayerEngine`**：基于 `@ohos.multimedia.avplayer` (AVPlayer)。
- **预留内核接入点**：通过同一接口可快速接入 `mpv`（C++ via NAPI）、`mdk` 等第三方内核，切换仅需替换 Engine 实例，UI 层无感。
- **`PlayerController`**：统一控制器，持有当前 Engine，向上暴露状态流（播放态、进度、缓冲、错误），向下转发操作。设置项（默认清晰度/倍速/解码策略）通过 Controller 注入。
- **系统音量调节（重要约束）**：HarmonyOS 不允许应用直接调用 `AudioVolumeGroupManager.setVolume` 调节系统音量，必须通过 `AVVolumePanel` 组件（`@kit.AudioKit`）完成。实现上：`PlayerControlView` 内放置隐藏的 `AVVolumePanel`（`volumeParameter.position` 设为 `(-1,-1)` 隐藏系统默认音量条、尺寸 0），手势滑动时更新其 `volumeLevel`（绝对档位）即驱动系统音量变化；`SystemAudioHelper` 仅负责通过 `AudioVolumeManager.on('streamVolumeChange')` 监听真实变化并回写 `controller.systemVolume`，Hub 据此显示实际值。`PlayerController` 不再持有 `setSystemVolume` 接口。

### AP-4: 持久化与设置导入导出（与 PiliPlus 同能力但更规范）
- **`PrefItem` 类**：含 `key` 和 `default` 两个属性，构造函数自动向 `prefItems` 集合添加 this；自身提供 `get`、`put`、`delete` 等方法，内部调用 preferences 实例的接口
- **`Pref` 类**：不提供 get/put/delete 方法，只提供 static 属性的 `PrefItem` 实例，以及导入、导出和重置所有等接口
- **导出**：直接调用鸿蒙 preferences 实例的 `getAll`，转成 JSON 字符串（含 schema 版本号）
- **导入**：从 JSON 字符串获取键值对列表，`put` 回 preferences；缺失的项不管，不重置为默认
- **重置**：调用 preferences 实例的接口清除所有设置
- **敏感数据隔离**：Cookie/Token 等认证数据不进入设置导出，单独加密存储（参见 AP-5）

### AP-5: 多用户与认证框架
- **`AccountManager`**：管理多账户列表 + 当前激活账户，切换账户时切换 Cookie/Token/用户级设置命名空间。
- **凭证安全存储**：AccessToken/Cookie 使用 `@ohos.security.huks` (HUKS) 或加密存储，不落明文。
- **账户隔离**：每账户的设置/历史/收藏缓存按 mid 分区。

### AP-6: UI 一次开发多设备适配
- **响应式布局**：使用栅格 (GridRow/GridCol)、断点 (Breakpoint)、自适应组件，**一次开发同时适配手机/平板/折叠屏**。
- **Navigation 组件**：基于系统 `Navigation`/`NavDestination`，天然支持分栏（平板/折叠屏双栏）与单栏（手机）切换。
- **多窗口/自由窗口**：支持小窗、自由窗口、悬浮窗，播放器需适配任意窗口尺寸。
- **资源限定**：使用 resources (fp/vp/limit) 而非硬编码尺寸，支持深色模式、动态取色、字体大小。

### AP-7: 弹幕渲染优先复用现成方案
- **首选 `@ohos/danmakuflamemaster`**（B站官方 DanmakuFlameMaster 的鸿蒙化迁移，OHPM v2.1.2），与 Bilibili 弹幕格式天然兼容。
- **备选 `@esky/barrage`** 或自绘 Canvas 兜底。
- 弹幕层与播放器解耦：弹幕渲染作为独立组件，订阅播放器时间轴。

## 目标
- **G1（V1 达标）**: 完成登录（扫码优先）+ 状态持久化 + 多用户切换框架，首页/搜索/动态可加载并跳转视频页，视频页支持播放/全屏/进度跳转/音量亮度调节，代码无报错、应用可运行。
- **G2**: 完善播放器（弹幕、清晰度、倍速、PiP）、评论、收藏、历史、直播、消息等模块，达到 PiliPlus 同等功能完善度。
- **G3**: 一次开发适配手机/平板/折叠屏，遵循鸿蒙设计语言，支持深色模式与动态取色。
- **G4**: 架构清晰、内核可插拔、设置可导入导出迁移，具备基础单元测试。

## 非目标（超出范围）
- 不做 iOS/Android/Web 端（聚焦鸿蒙）。
- 不实现直播推流、应用内支付、视频持久化下载（仅支持在线播放与缓存）。
- 不逆向 Bilibili 协议以外的私有协议。
- V1 不强求高测试覆盖率（详见 AP-8），但必须保证编译通过、应用可运行。

## 背景与上下文
- **参考项目**: PiliPlus（Flutter 跨平台 Bilibili 客户端）—— 作为**功能与 API 调用参考**，不作为架构范本。
- **技术栈**: HarmonyOS NEXT (API 14+)、ArkUI 声明式、ArkTS、Stage 模型、Navigation 组件。
- **目标设备**: 手机、平板、折叠屏（一次开发多端部署）。
- **三方依赖**:
  - 弹幕：`@ohos/danmakuflamemaster`（首选）
  - 网络：`@ohos.net.http`
  - 持久化：`@ohos.data.preferences` / `@ohos.data.relationalStore`
  - 媒体：`@ohos.multimedia.avplayer` / `@ohos.multimedia.media`（默认内核）
  - 凭证：`@ohos.security.huks`（密钥保险箱）

## 功能需求

### FR-1: 首页与内容推荐（V1 核心）
- 首页推荐视频流（Web WBI 签名 + App 双通道），下拉刷新、上拉分页
- 热门视频、分区排行
- 推荐过滤（黑名单用户、关键词、低赞比）
- 视频卡片点击跳转视频详情页

### FR-2: 视频播放器（V1 核心 + 后续完善）
- **V1**: 播放、暂停、全屏、进度跳转、音量/亮度调节、横竖屏
- **后续**: 多清晰度、倍速、画中画、弹幕叠加、字幕、进度记忆与上报、自动连播
- **架构**: 经 `IPlayerEngine` → `PlayerController`，默认 `AvPlayerEngine`，预留 mpv/mdk 接入

### FR-3: 用户账户与多用户（V1 核心）
- **扫码登录优先**（TV 端 qrcode 流程），密码/短信登录次之
- 登录状态持久化、自动登录
- **多用户切换框架**：账户列表、当前账户、切换时切换数据空间
- 退出登录、设备登录管理

### FR-4: 弹幕互动
- 视频弹幕实时显示（`@ohos/danmakuflamemaster`）
- 弹幕发送、样式设置、屏蔽（关键词/正则/用户）、密度调节、显隐开关
- 直播弹幕 WebSocket 实时收发

### FR-5: 直播观看
- 直播列表/分区、直播流播放、弹幕 WebSocket、互动（点赞/关注/分享）、屏蔽词

### FR-6: 搜索功能（V1 核心）
- 关键词搜索（视频/直播/用户/番剧/文章）、建议补全、历史、热搜、分类 Tab、高级筛选
- 搜索结果视频项可跳转视频页

### FR-7: 动态与社交（V1 部分：动态流加载）
- **V1**: 动态信息流加载、可点击跳转视频页
- **后续**: 动态详情、点赞/评论/转发、发布动态、话题广场

### FR-8: 收藏与历史
- 收藏夹列表/管理（创建/编辑/删除/排序）、收藏内视频浏览
- 稍后再看、历史记录浏览与删除

### FR-9: 用户主页
- UP 主信息、视频/动态/收藏 Tab、关注/粉丝列表、关注/拉黑操作

### FR-10: 评论系统
- 评论列表、楼中楼、发表/回复、点赞/点踩、删除、@功能

### FR-11: 消息与通知
- 私信、系统消息、回复我的、@我的、收到的赞、未读计数

### FR-12: 设置中心（V1 部分）
- **V1**: 基础播放设置（清晰度/音量亮度）+ 主题外观设置
- **后续**: 完整设置项、**设置导入导出**（AP-4）、隐私、推送、关于、日志

### FR-13: 番剧/追剧 / FR-14: 音乐音频
- 番剧索引/详情/追番/排行；音乐列表/播放/MediaSession

## 非功能需求

### NFR-1: 性能
- 首页首屏 < 2s、视频起播 < 1s、列表/弹幕 ≥ 60fps、视频播放内存 < 500MB

### NFR-2: UI/UX
- 遵循 HarmonyOS Design、深色/浅色自动、动态取色、响应式多设备、横竖屏、流畅转场（AP-6）

### NFR-3: 代码质量（V1 适度要求，详见 AP-8）
- 分层清晰、ArkTS 严格模式、模块单一职责
- V1 必须保证：**编译无报错、应用可运行、核心流程可用**
- 后续逐步补充单元测试

### NFR-4: 网络与数据
- 统一 HTTP 客户端、WBI 签名、Cookie 管理、异常处理、本地缓存

### NFR-5: 兼容性
- HarmonyOS NEXT API 14+，手机/平板/折叠屏，多窗口

### AP-8: 测试与质量保证优先级（V1 降级）
- **V1**: 测试覆盖率与测试用例为**低优先级**；首要目标是代码无报错、应用可运行、核心流程（登录/首页/搜索/动态/视频播放）可用。
- 单元测试可在 V1 完成后补充，聚焦网络层、签名、持久化导入导出、播放器状态机等纯逻辑。

## 约束
- **技术**: ArkUI 声明式 + ArkTS 严格模式 + HarmonyOS NEXT API 14+；仅用原生 SDK + 已适配鸿蒙的三方库
- **架构**: 必须遵守 AP-1 ~ AP-7 架构原则

## 假设
- A1: Bilibili API 近期保持稳定
- A2: 用户拥有或愿意注册 Bilibili 账户
- A3: 鸿蒙设备硬件性能足以支持视频播放

## 验收标准

> **V1 达标验收（最高优先级）**

### AC-V1-1: 扫码登录与多用户
- **Given**: 用户未登录
- **When**: 选择扫码登录，使用 Bilibili App 扫码并确认
- **Then**: 登录成功、获取 Token、持久化登录态、重启后自动登录；支持多账户切换框架
- **验证**: `programmatic`

### AC-V1-2: 首页/搜索/动态加载与跳转
- **Given**: 用户已登录
- **When**: 进入首页/搜索/动态页
- **Then**: 推荐视频、搜索结果、动态流正确加载；点击视频项可跳转视频详情页
- **验证**: `programmatic`

### AC-V1-3: 视频页基础播放
- **Given**: 用户进入视频详情页
- **When**: 视频加载并播放
- **Then**: 支持播放/暂停、全屏切换、进度跳转、音量/亮度调节
- **验证**: `programmatic`

### AC-V1-4: 可运行性
- **Given**: V1 代码完成
- **When**: 编译并安装运行
- **Then**: 编译无报错、应用正常启动、核心流程可用、无崩溃
- **验证**: `programmatic`

> **架构达标验收**

### AC-A-1: 播放器内核可切换
- **Given**: 实现了 `IPlayerEngine` 接口与 `AvPlayerEngine`
- **When**: 新增 mpv/mdk 内核
- **Then**: 仅需实现接口并替换 Engine 注入，UI 与 Controller 层无需改动
- **验证**: `human-judgment`

### AC-A-2: 设置导入导出
- **Given**: 用户有多项非默认设置
- **When**: 导出设置后再导入（仅含非默认项）
- **Then**: 导出文件仅含非默认值项；导入后设置恢复；缺失项保留原设置（不重置为默认）
- **验证**: `programmatic`

### AC-A-3: 网络状态模型
- **Given**: 网络层实现 `Result<T,E>` + `DataState<T>`
- **When**: 任意请求发生
- **Then**: 请求结果与 UI 状态正确分离流转，错误通过统一 `AppError` 传递
- **验证**: `programmatic`

### AC-A-4: 多设备适配
- **Given**: 同一份代码
- **When**: 在手机/平板/折叠屏运行
- **Then**: 布局自动适配，单栏/分栏正确切换
- **验证**: `human-judgment`

> **功能完善度验收（对齐 PiliPlus）**

### AC-F-1: 弹幕
- **Given**: 视频播放中
- **When**: 开启弹幕
- **Then**: 弹幕正确渲染、可发送、可屏蔽、可调样式/密度
- **验证**: `programmatic`

### AC-F-2: 直播
- **Given**: 进入直播间
- **When**: 观看直播
- **Then**: 流播放正常、WebSocket 弹幕实时收发
- **验证**: `programmatic`

### AC-F-3: 评论/收藏/历史/消息/用户主页/番剧/音乐
- **Given**: 各模块完成
- **When**: 执行对应操作
- **Then**: 功能与 PiliPlus 同等可用
- **验证**: `programmatic`

## 开放问题
- [ ] 扫码登录采用 TV 端 (`passport-tv-login`) 还是 Web 端流程？建议 TV 端（PiliPlus 同款，免 Web 风控）
- [ ] 是否实现 DLNA 投屏 / WebDAV 同步（V1 不做，后续评估）
- [ ] mpv/mdk 内核接入的具体时机与 NAPI 封装方案
- [ ] 动态取色采用系统 CorePalette 还是自实现

## P2 实现进度（2026-08-05）

> 与 tasks.md / checklist.md 保持同步。以下 P2 功能已实现并通过全量编译（0 报错）：

- **视频详情互动（Task 13）**：相关视频、分P 切换、点赞/投币/收藏/一键三连、稍后再看、UP 主页入口
- **评论系统（Task 14）**：主评论分页、楼中楼、点赞、发表/回复（视频 type=1、动态 type=17）
- **直播（Task 15）**：分区列表、直播间列表、直播流经 PlayerController 播放、WebSocket 弹幕收发、发弹幕、屏蔽词
- **收藏/历史/稍后再看（Task 16）**：收藏夹与收藏内视频、稍后再看增删清、历史记录分页/删除/清空
- **用户主页（Task 17）**：空间信息、统计、投稿/动态/收藏 Tab、关注/取关
- **动态详情与发布（Task 18）**：动态详情、点赞、评论、文字动态发布（可带话题）、话题广场与话题流
- **番剧与音乐（Task 20）**：番剧排行/索引/详情/选集播放/追番；音乐分区排行；MediaSession（AVSession）集成到播放器

**说明**：图文动态的 BFS 图片上传、动态转发动作、直播间关注/分享、评论点踩/删除 UI、
收藏夹管理、拉黑与粉丝列表、AI 总结等仍属相邻 P3 任务（Task 26~30），未在本次 P2 范围内实现。
