# 鸿蒙 Bilibili 第三方应用 (OHB) - 实现计划

> **优先级原则**: V1 达标任务（P0）→ 架构达标任务（P1）→ 功能完善任务（P2）→ 质量与打磨（P3）。
> 依赖方向：UI → ViewModel → Repository → Network/Storage。所有任务须遵守 spec.md 的 AP-1~AP-8 架构原则。

---

# P0: V1 达标任务（最高优先级，必须完成）

## [x] Task 1: 项目基础架构与分层骨架
- **优先级**: high
- **依赖**: 无
- **描述**:
  - 搭建鸿蒙 ArkUI 项目（Stage 模型），配置 `bundleName`、签名、API 14+、设备类型（default/tablet）
  - 建立分层目录：`common/`(通用组件/工具)、`data/`(repository/datasource)、`network/`(http/wbi/cookie)、`player/`(引擎抽象+控制器)、`models/`(数据模型)、`pages/`(页面)、`viewmodel/`、`services/`(account/storage)、`theme/`、`utils/`
  - 集成 Navigation 组件作为主路由，天然支持单栏/分栏自适应（AP-6）
  - 配置深色/浅色主题、动态取色基础
  - 实现应用级常量（API BaseUrl、UA、超时）
  - 创建 EntryAbility 与主框架壳
- **验收标准**: AC-V1-4, AC-A-4
- **测试需求**:
  - `programmatic` TR-1.1: 项目编译通过、可安装运行、显示主框架
  - `programmatic` TR-1.2: 深/浅色主题切换正常
  - `programmatic` TR-1.3: Navigation 路由可跳转
  - `human-judgement` TR-1.4: 目录分层清晰、符合 AP-1

## [x] Task 2: 网络层 + Result/DataState 状态模型
- **优先级**: high
- **依赖**: Task 1
- **描述**:
  - 封装统一 HTTP 客户端（`@ohos.net.http`），支持 GET/POST、表单/JSON、超时、重试
  - **实现 `Result<T, E>`**（Ok/Err）+ **`DataState<T>`** 状态机（Idle/Loading/Refreshing/Data/Error/Empty）（AP-2，**不照搬 PiliPlus 三态**）
  - **统一 `AppError`** 模型（code/message/retryable/cause）
  - 实现 WBI 签名算法（参考 PiliPlus `wbi_sign.dart` 算法，非照搬代码）
  - 实现 API 常量定义（参考 PiliPlus `api.dart` 的 URL 与参数）
  - 实现 Cookie 管理（`@ohos.data.preferences` 持久化）
  - 实现请求拦截（token 注入、UA、错误转换、日志）
- **验收标准**: AC-V1-2, AC-A-3
- **测试需求**:
  - `programmatic` TR-2.1: GET/POST 正确收发
  - `programmatic` TR-2.2: WBI 签名与参考算法输出一致
  - `programmatic` TR-2.3: Cookie 存取正常
  - `programmatic` TR-2.4: `DataState` 状态流转正确、`AppError` 错误传递正确

## [x] Task 3: 数据模型层（V1 必需子集）
- **优先级**: high
- **依赖**: Task 2
- **描述**:
  - **V1 仅实现必需模型**：推荐视频、搜索结果、动态流、视频详情、播放地址、用户信息、登录响应
  - 其余模型（收藏/历史/评论/直播/消息等）在 P2 对应任务中按需补全
  - 使用 ArkTS class/interface + JSON 序列化工具
- **验收标准**: AC-V1-2, AC-V1-3
- **测试需求**:
  - `programmatic` TR-3.1: V1 模型 JSON 反序列化/序列化正确

## [x] Task 4: 多用户与认证框架（扫码登录优先）
- **优先级**: high
- **依赖**: Task 2, Task 3
- **描述**:
  - **`AccountManager`**：多账户列表 + 当前激活账户（AP-5）
  - **扫码登录优先**（TV 端 `passport-tv-login` 流程：getTVCode → 二维码生成 → qrcodePoll 轮询 → qrcodeConfirm）
  - 密码/短信登录次之（V1 可暂缓，扫码达标即可）
  - 凭证安全存储（`@ohos.security.huks` 或加密，**不落明文**）
  - 登录态持久化、自动登录、Token 刷新
  - 账户切换时切换数据空间（Cookie/用户级设置）
  - 退出登录
  - 登录页 UI（二维码 + 状态提示）
- **验收标准**: AC-V1-1
- **测试需求**:
  - `programmatic` TR-4.1: 扫码二维码正确生成
  - `programmatic` TR-4.2: 轮询状态机正确（等待→扫描→确认→成功）
  - `programmatic` TR-4.3: 登录态持久化、重启自动登录
  - `programmatic` TR-4.4: 多账户切换数据空间正确隔离
  - `human-judgement` TR-4.5: 登录页 UI 美观

## [x] Task 5: 视频播放器内核抽象与 AVPlayer 实现
- **优先级**: high
- **依赖**: Task 2, Task 3
- **描述**:
  - **`IPlayerEngine` 接口**（AP-3）：play/pause/seek/setVolume/setBrightness/setSpeed/setQuality/snapshot/release + 状态流（state/position/duration/buffered/error）
  - **`AvPlayerEngine`**：基于 `@ohos.multimedia.avplayer`
  - **`PlayerController`**：统一控制器，持有 Engine，向上暴露状态流，注入设置
  - **V1 能力**：播放/暂停、全屏、进度跳转、音量调节、亮度调节、横竖屏
  - 预留 mpv/mdk 接入点（接口已抽象即可，V1 不实现具体内核）
  - 播放器 UI 控制层（V1 基础控件）
- **验收标准**: AC-V1-3, AC-A-1
- **测试需求**:
  - `programmatic` TR-5.1: 视频可播放/暂停
  - `programmatic` TR-5.2: 全屏切换正常
  - `programmatic` TR-5.3: 进度跳转正常
  - `programmatic` TR-5.4: 音量/亮度调节正常
  - `programmatic` TR-5.5: `IPlayerEngine` 接口抽象完整，可替换实现
  - `human-judgement` TR-5.6: 控制层 UI 可用

## [x] Task 6: 首页推荐流
- **优先级**: high
- **依赖**: Task 2, Task 3, Task 4
- **描述**:
  - 推荐视频 API（Web WBI + App 双通道，参考 PiliPlus 参数）
  - 推荐过滤（黑名单/关键词/低赞比）
  - 视频卡片组件 + 响应式列表/瀑布流
  - 下拉刷新、上拉分页
  - 卡片点击跳转视频页
  - ViewModel 用 `DataState` 管理状态
- **验收标准**: AC-V1-2
- **测试需求**:
  - `programmatic` TR-6.1: 推荐列表加载显示
  - `programmatic` TR-6.2: 刷新/分页正常
  - `programmatic` TR-6.3: 黑名单过滤生效
  - `human-judgement` TR-6.4: 卡片 UI 美观、响应式适配

## [x] Task 7: 搜索功能
- **优先级**: high
- **依赖**: Task 2, Task 3
- **描述**:
  - 搜索建议补全、热搜、分类搜索（视频/直播/用户/番剧/文章）
  - 搜索历史本地持久化
  - 高级筛选（时长/分区/排序）
  - 搜索结果视频项可跳转视频页
  - 搜索页 UI + ViewModel
- **验收标准**: AC-V1-2
- **测试需求**:
  - `programmatic` TR-7.1: 建议实时返回
  - `programmatic` TR-7.2: 分类搜索结果正确
  - `programmatic` TR-7.3: 历史存取正常
  - `human-judgement` TR-7.4: 搜索交互流畅

## [x] Task 8: 动态流加载（V1：仅加载与跳转）
- **优先级**: high
- **依赖**: Task 2, Task 3, Task 4
- **描述**:
  - 关注动态 API（参考 PiliPlus `followDynamic`）
  - 动态卡片展示，支持下拉刷新/分页
  - 动态内视频项可跳转视频页
  - **V1 不做**：点赞/评论/转发/发布动态（P2）
  - 动态页 ViewModel
- **验收标准**: AC-V1-2
- **测试需求**:
  - `programmatic` TR-8.1: 动态流正确加载
  - `programmatic` TR-8.2: 视频项跳转正常
  - `human-judgement` TR-8.3: 动态卡片 UI 合理

## [x] Task 9: 视频详情页（V1：播放+基础信息）
- **优先级**: high
- **依赖**: Task 5, Task 6
- **描述**:
  - 视频详情 API（标题/简介/UP主/分P）
  - 视频流地址获取（UGC 优先）
  - 接入 `PlayerController` 播放
  - V1 详情页基础布局（播放器 + 标题 + UP主 + 简介）
  - **V1 不做**：弹幕/三连/评论/相关（P1/P2）
- **验收标准**: AC-V1-3
- **测试需求**:
  - `programmatic` TR-9.1: 详情正确加载
  - `programmatic` TR-9.2: 视频流地址获取并播放
  - `human-judgement` TR-9.3: 详情页布局合理

## [x] Task 9.1: 播放器控制 UI 优化（图层优先级 + 实时状态 + 音量监听）
- **优先级**: high
- **依赖**: Task 5, Task 9
- **描述**:
  - **Stack 图层优先级修正**（底→顶）：AVVolumePanel（隐藏）→ Hub（音量/亮度提示）→ 音量/亮度滑动监听层 → 控制层（进度条、播放/暂停、全屏按钮）
    - 控制层置于最顶层，避免被手势层遮挡导致进度条不可拖、按钮点不动、状态不更新
    - 底部控制条空白区域 `hitTestBehavior(None)`，透传给手势层；按钮与 Slider 自身仍可交互
  - **实时状态修复**（参考 PiliPlus 连续进度流）：
    - 播放中每 500ms 通过 `syncProgress()` 轮询内核 `currentTime` 兜底刷新进度
    - `AvPlayerEngine.getPosition()` 优先读取实时 `currentTime`
    - 播放/暂停按钮图标由 `@ObjectLink` 绑定 `controller.state` 实时刷新
  - **音量监听修复**：
    - `SystemAudioHelper` 升级为多监听者（`addVolumeListener`/`removeVolumeListener`），Controller 回写 + UI Hub 提示并存
    - `PlayerControlView` 显式注册监听替代不可靠的 `@Watch + @ObjectLink` 方案；硬件音量键变化也会弹出 Hub
    - Hub 显示 `streamVolumeChange` 回写的**实际监听值**（文字 + 细进度条），并同步面板档位
  - `PlayerController` 增加 `syncSystemVolume()` / `syncProgress()`，release 时反注册音量监听避免泄漏
- **验收标准**: AC-V1-3
- **测试需求**:
  - `programmatic` TR-9.1.1: 全量编译 0 报错
  - `human-judgement` TR-9.1.2: 进度条实时前进、可拖动 seek
  - `human-judgement` TR-9.1.3: 播放/暂停按钮状态实时切换
  - `human-judgement` TR-9.1.4: 滑动调节音量/亮度时 Hub 显示实际值，硬件音量键同步弹出 Hub

## [x] Task 9.2: 播放器体验修复（全屏返回黑屏 + 实时刷新 + 手势增强）
- **优先级**: high
- **依赖**: Task 9.1
- **描述**:
  - **修复全屏返回黑屏（有声音无画面）**：
    - 根因：`AvPlayerEngine.setSurface('')` 对空串不生效，全屏退出时 AVPlayer 仍指向已销毁的全屏 surface；
      详情页 XComponent 的 surface 在全屏覆盖期间失效，重绑旧 id 无效
    - 方案：`VideoDetailPage` 在全屏返回时卸载并重建 XComponent（`xcMounted` 开关），
      `onLoad` 用全新 surface id 重新绑定；`onPageHide` 时卸载释放 surface
  - **进度条/音量/播放态实时刷新**：
    - 弃用不可靠的 `@ObjectLink` 观察链路，改为 controller + 250ms UI 同步定时器，
      将内核状态拷贝到本地 `@State` 镜像（posMs/durMs/playing/vol/bri/fullscreen）
    - 播放中每 250ms 从内核同步真实进度（`syncProgress` 读 `currentTime`）
  - **Hub 居中**：移除偏移，位于视频中心；支持音量/亮度/进度预览三态
  - **手势增强**（参考 PiliPlus）：
    - 去掉中央播放/暂停按钮（保留底部控制条）
    - 双击播放/暂停、单击切换控制层
    - 水平滑动设置进度：滑动中 Hub 显示目标进度（只预览），松手才真正 seek
    - 垂直滑动保持左亮度/右音量
- **验收标准**: AC-V1-3
- **测试需求**:
  - `programmatic` TR-9.2.1: 全量编译 0 报错
  - `human-judgement` TR-9.2.2: 全屏进入/退出后画面正常恢复
  - `human-judgement` TR-9.2.3: 进度条/时间/播放暂停图标实时刷新
  - `human-judgement` TR-9.2.4: 连续按音量键 Hub 值实时变化
  - `human-judgement` TR-9.2.5: 双击播放/暂停、水平滑动预览并跳转进度

## [x] Task 9.3: 播放器实例归 VM 持有 + 全屏 surface 重建（彻底修复黑屏）
- **优先级**: high
- **依赖**: Task 9.2
- **描述**:
  - **根因确认**：AVPlayer 在 playing 态直接改 `surfaceId` 时，若旧 surface 正在销毁或新 surface 未稳定
    （全屏退出时两者同时发生），播放器会进入不可恢复的坏状态 → 黑屏（仍有声音），且再次全屏也黑屏
  - **架构调整（按需求：VM 持有视频实例）**：
    - `VideoDetailViewModel.controller` 持有 `PlayerController`（单一所有者），去掉 `bindPlayer`
    - 视频页直接使用 `vm.controller`；全屏页经 `PlayerControllerHolder` 访问同一实例
    - 视频页条件渲染：`!isFullscreen && xcReady` 才挂载 XComponent——全屏期间本页完全不渲染视频，
      退出全屏后 `onPageShow` 延迟 400ms（等窗口转场/方向还原完成）再挂载
  - **surface 切换改为重建播放器**（`IPlayerEngine.rebindSurface`）：
    - `AvPlayerEngine.rebindSurface`：释放旧播放器 → 用同一源重建 → prepared 后自动起播
    - `PlayerController.rebindSurface(sid, positionMs)`：记录 `pendingSeekMs`，prepared 后 seek 回原进度
    - 两个页面的 XComponent `onLoad` 均调用 `rebindSurface`，进入/退出全屏都走重建路径，行为对称可靠
- **验收标准**: AC-V1-3
- **测试需求**:
  - `programmatic` TR-9.3.1: 全量编译 0 报错
  - `human-judgement` TR-9.3.2: 全屏进入/退出后画面均正常恢复，且可反复进出全屏
  - `human-judgement` TR-9.3.3: 全屏切换后播放进度连续（从原进度继续）

## [x] Task 9.4: 全屏 surface 重建改确定性驱动（修复真机仍黑屏）
- **优先级**: high
- **依赖**: Task 9.3
- **描述**:
  - **v2/v3 失效根因复盘**：两个依赖都不可靠——
    1. 依赖 `onPageShow/onPageHide` 生命周期回调驱动 XComponent 重建（NavDestination 内容页实测可能不触发）
    2. 重建 XComponent 时**复用同一个 XComponentController**，可能拿到失效的旧 surface id
  - **v4 方案（完全确定性，不依赖生命周期回调与 @Observed）**：
    - 详情页 200ms 轮询 `controller.isFullscreen`（普通字段直读），本地 `@State fsMirror` 镜像驱动条件渲染：
      进入全屏 → 卸载本页 XComponent（不渲染视频）；退出全屏 → 延迟 300ms 重建
    - 重建时**更换全新 XComponentController**（普通字段 + `@State xcEpoch` 递增触发重绘），
      强制生成新节点与新 surface id
    - `onLoad` 重绑 + 100ms×15 次 surface id 轮询兜底（`rebindDone` 幂等防重复），
      绑定后重建播放器（rebindSurface）并 seek 回原进度
  - **进入全屏恢复轻量 bindSurface**（目标 surface 全新有效，实测可用）：
    v3 对入口也做重建反而引入卡顿；仅退出方向走重建，行为不对称但各取所需
- **验收标准**: AC-V1-3
- **测试需求**:
  - `programmatic` TR-9.4.1: 全量编译 0 报错
  - `human-judgement` TR-9.4.2: 退出全屏画面恢复、进度连续，反复进出全屏均正常
  - `human-judgement` TR-9.4.3: 入口无重建卡顿

## [x] Task 10: V1 集成与可运行性验证
- **优先级**: high
- **依赖**: Task 1~9
- **描述**:
  - 主框架导航整合（首页/搜索/动态/我的 Tab）
  - 端到端串联：登录→首页→搜索→动态→视频播放
  - 全量编译、修复所有报错
  - 真机/模拟器运行验证，修复崩溃
  - 多设备形态（手机/平板/折叠屏）基础适配验证
- **验收标准**: AC-V1-1, AC-V1-2, AC-V1-3, AC-V1-4
- **测试需求**:
  - `programmatic` TR-10.1: 全量编译 0 报错
  - `programmatic` TR-10.2: 端到端流程可用
  - `programmatic` TR-10.3: 多设备形态可运行
  - `human-judgement` TR-10.4: V1 整体体验可用

---

# P1: 架构达标任务

## [x] Task 11: 设置中心与导入导出
- **优先级**: medium
- **依赖**: Task 1
- **描述**:
  - 定义 `PrefItem` 类，含 `key` 和 `default` 两个属性，构造函数自动向 `prefItems` 添加 this
  - `PrefItem` 自身提供 `get`、`put`、`delete` 等方法，内部调用 preferences 实例的接口
  - `Pref` 类不提供这些方法，只提供 static 属性的 `PrefItem` 实例，以及导入、导出和重置所有等接口
  - **导出**：直接调用鸿蒙 preferences 实例的 `getAll`，转成 JSON 字符串
  - **导入**：从 JSON 字符串获取键值对列表，`put` 回 preferences，缺失的项不管（不重置为默认）
  - **重置**：调用 preferences 实例的接口清除所有设置
  - 设置页 UI（播放/外观/搜索/隐私/关于/日志）
  - 导入导出 UI（文件选择/分享）
  - 已实现：`PrefItem`（key/default，构造注册，get/put/delete 委托 preferences）、
    `Pref`（static 设置项 + 导出/导入/重置）；导出= getAllSync 过滤非默认项 + schemaVersion；
    导入= 仅写回文件中存在的已知 key（缺失项保留原设置）；重置= preferences.clear；
    设置页含播放（清晰度/倍速/自动连播/弹幕）、外观（深色模式即时生效）、搜索（历史开关联动 SearchRepository）、
    隐私（屏蔽关键词/黑名单 UP/低赞比联动 VideoRepository 过滤）、日志、关于（版本）；
    导入导出走 `DocumentViewPicker` 选择/保存 JSON 文件；默认清晰度/倍速在视频详情加载时实际生效
- **验收标准**: AC-A-2, AC-A-3
- **测试需求**:
  - `programmatic` TR-11.1: 各设置独立存取
  - `programmatic` TR-11.2: 导出仅含非默认项
  - `programmatic` TR-11.3: 导入后恢复、缺失项保留原设置
  - `human-judgement` TR-11.4: 设置页结构清晰

## [ ] Task 12: 视频播放器完善（弹幕+清晰度+倍速+PiP）
- **优先级**: medium
- **依赖**: Task 5
- **描述**:
  - 多清晰度切换、倍速、画中画、进度记忆与上报、自动连播
  - **弹幕渲染**：集成 `@ohos/danmakuflamemaster`（AP-7），弹幕层独立组件订阅播放器时间轴
  - 弹幕发送、样式、屏蔽、密度、显隐
  - 字幕支持
- **验收标准**: AC-F-1, AC-A-1
- **测试需求**:
  - `programmatic` TR-12.1: 清晰度/倍速切换正常
  - `programmatic` TR-12.2: PiP 正常
  - `programmatic` TR-12.3: 弹幕渲染流畅 ≥60fps
  - `programmatic` TR-12.4: 弹幕发送/屏蔽正常
  - `human-judgement` TR-12.5: 播放器 UI 完善

---

# P2: 功能完善任务（对齐 PiliPlus）

## [x] Task 13: 视频详情互动（相关/分P）
- **优先级**: medium
- **依赖**: Task 9
- **描述**: 相关视频、分P/选集、追番、稍后再看、视频详情页完善 UI
  - 已实现：相关视频（`/x/web-interface/archive/related`）、分P 点击切换（重取 playurl 并起播）、
    点赞/投币/收藏/一键三连操作栏、稍后再看加入、UP 主行跳转用户主页、互动计数本地即时更新
  - 说明：追番入口在番剧详情页（Task 20）；AI 总结归属 P3（Task 26）
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-13.2: 相关视频/分P 正常
  - `human-judgement` TR-13.3: 详情页完善

## [x] Task 14: 评论系统
- **优先级**: medium
- **依赖**: Task 9
- **描述**: 评论列表/楼中楼/点赞点踩；评论组件与 ViewModel
  - 已实现：主评论分页（`/x/v2/reply/main`）、楼中楼（`/x/v2/reply/reply`）、
    点赞/取消赞（`/x/v2/reply/action`）、发表顶层/楼中楼回复（`/x/v2/reply/add`）、
    删除接口（`/x/v2/reply/del`，UI 入口随 P3 评论管理补充）；
    评论组件同时支持视频（type=1）与动态（type=17，oid 走字符串避免精度丢失）
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-14.1: 评论列表分页加载
  - `programmatic` TR-14.3: 点赞正常

## [x] Task 15: 直播观看
- **优先级**: medium
- **依赖**: Task 2, Task 5
- **描述**: 直播列表/分区、直播流接入 PlayerController、WebSocket 弹幕、互动、屏蔽词
  - 已实现：分区 + 直播间列表（App 通道 `getAreaList`/`getList`）、
    直播流播放（`getRoomPlayInfo` 解析 host+base_url+extra，经 PlayerController）、
    WebSocket 弹幕（`getDanmuInfo` 取 token → wss 认证/心跳/JSON 弹幕解析）、
    发弹幕（`/msg/send`）、屏蔽词增删（`AddShieldKeyword`/`DelShieldKeyword`）
  - 说明：直播间关注/分享等互动入口留待后续打磨（不影响 TR-15.1~15.3）
- **验收标准**: AC-F-2
- **测试需求**:
  - `programmatic` TR-15.1: 直播列表加载
  - `programmatic` TR-15.2: 直播流播放
  - `programmatic` TR-15.3: WebSocket 弹幕收发

## [x] Task 16: 收藏与历史/稍后再看
- **优先级**: medium
- **依赖**: Task 4, Task 9
- **描述**: 收藏内视频、稍后再看、历史记录
  - 已实现：收藏夹列表（`fav/folder/created/list-all`）+ 收藏夹内视频分页（`fav/resource/list`）+
    收藏/移除（`fav/resource/batch-deal`）、稍后再看列表/加入/移除/清空
    （`toview/web`、`toview/add`、`toview/v2/dels`、`toview/clear`）、
    历史记录游标分页/删除/清空（`history/cursor`、`history/delete`、`history/clear`）
  - 说明：收藏夹增删改查/排序归属 P3（Task 28）
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-16.2: 稍后再看/历史正常

## [x] Task 17: 用户主页与社交
- **优先级**: medium
- **依赖**: Task 4
- **描述**: UP 主信息、视频/动态/收藏 Tab
  - 已实现：空间信息（`space/wbi/acc/info`）+ 关系统计（`relation/stat`）、
    投稿列表（`space/wbi/arc/search`）、用户动态（`polymer/web-dynamic/v1/feed/space`）、
    用户收藏夹（`fav/folder/created/list-all`）、关注/取关（`relation/modify`）；
    入口：视频详情 UP 行、搜索结果用户行、动态作者行
  - 说明：拉黑与关注/粉丝列表归属 P3（Task 29）
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-17.1: 用户主页加载

## [x] Task 18: 动态详情与发布
- **优先级**: low
- **依赖**: Task 8
- **描述**: 动态详情、点赞/评论/转发、发布动态(图文)、话题广场
  - 已实现：动态详情（`polymer/web-dynamic/v1/detail`）、点赞（`dyn/thumb`）、
    评论（type=17 复用评论组件）、文字动态发布（`dyn/feed/create/dyn`，支持话题绑定）、
    话题广场（`topic/web/dynamic/rcmd` + `feed/topic`）
  - 说明：转发动作与图文上传（BFS 图片上传）暂未接入，留待后续；不影响 TR-18.1/18.2
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-18.1: 动态详情展示
  - `programmatic` TR-18.2: 互动/发布成功

## [x] Task 20: 番剧/追剧与音乐音频
- **优先级**: low
- **依赖**: Task 5
- **描述**: 番剧索引/详情/追番/排行；音乐列表/播放/MediaSession
  - 已实现：番剧排行（`pgc/season/rank/web/list`）与索引（`pgc/season/index/result`）、
    番剧详情/选集播放（`pgc/view/web/season` + `pgc/player/web/v2/playurl`）、追番/取消追番
    （`pgc/web/follow/add|del`）；音乐分区排行（`ranking/v2?rid=3`）列表播放；
    MediaSession 经 `@kit.AVSessionKit` 集成到 PlayerController（锁屏播放/暂停/seek）
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-20.1: 番剧模块正常
  - `programmatic` TR-20.2: 音乐播放 + MediaSession

## [x] Task 24: 底部导航栏沉浸光感适配（P2）
- **优先级**: medium
- **依赖**: Task 1
- **描述**:
  - 适配 HarmonyOS 沉浸光感（Immersive Light）：底部 Tab 栏使用 barFloatingStyle + ImmersiveMaterial 材质效果，实现沉浸视觉
  - **兼容回退**：通过 `deviceInfo.sdkApiVersion >= 26` 检测，不支持时回退为普通 `barBackgroundColor` 不透明导航栏
  - 使用 `Tabs.barFloatingStyle({ barBottomMargin: 0, systemMaterial: new uiMaterial.ImmersiveMaterial({...}) })` 设置浮动沉浸材质
  - 配合 `barOverlap(true)` 让内容延伸至导航栏下方，透过半透明材质显现沉浸效果
  - 支持时 `barBackgroundColor` 设为透明（`Color.Transparent`），让材质透出
  - 不支持时使用普通不透明背景色（`AppColors.CARD_BG`）
  - 两套 Tabs Builder：`buildImmersiveTabs()`（沉浸版）和 `buildNormalTabs()`（回退版），通过 `if/else` 在 `build()` 中切换
  - ImmersiveHelper 工具类封装兼容检测与材质实例创建
  - **SDK 说明**：@kit.UIDesignKit（HDS 组件 HdsTabs/hdsMaterial）仅在 HarmonyOS SDK 中可用，当前项目使用 OpenHarmony SDK，因此使用 @kit.ArkUI 提供的 uiMaterial API（since 26.0.0）
- **验收标准**: AC-A-4
- **测试需求**:
  - `programmatic` TR-24.1: 支持 API 26 设备上底部导航栏呈现沉浸光感材质效果
  - `programmatic` TR-24.2: 不支持的设备回退为普通不透明导航栏，功能正常
  - `human-judgement` TR-24.3: 沉浸效果视觉自然，Tab 内容无遮挡、无裁切

---

# P3: 质量与打磨

## [ ] Task 26: 视频详情互动-三连/AI总结
- **优先级**: low
- **依赖**: Task 13
- **描述**: 三连(点赞/投币/收藏)、AI总结
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-26.1: 三连操作成功、状态更新

## [ ] Task 27: 评论系统-发表回复/删除/@
- **优先级**: low
- **依赖**: Task 14
- **描述**: 评论发表回复、删除、@功能
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-27.1: 发表回复成功
  - `programmatic` TR-27.2: 删除评论正常
  - `programmatic` TR-27.3: @功能正常

## [ ] Task 28: 收藏夹增删改查
- **优先级**: low
- **依赖**: Task 16
- **描述**: 收藏夹管理（增删改查）
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-28.1: 收藏夹增删改查正常

## [ ] Task 29: 用户主页与社交-关注/拉黑
- **优先级**: low
- **依赖**: Task 17
- **描述**: 关注粉丝列表、关注/拉黑操作
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-29.1: 关注粉丝列表加载正常
  - `programmatic` TR-29.2: 关注/拉黑操作成功

## [ ] Task 30: 消息与通知
- **优先级**: low
- **依赖**: Task 19
- **描述**: 私信、系统消息、回复我的、@我的、收到的赞、未读计数
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-30.1: 未读计数
  - `programmatic` TR-30.2: 私信收发
  - `programmatic` TR-30.3: 各消息 Tab 正常

## [ ] Task 21: 单元测试与质量保障
- **优先级**: low（AP-8: V1 降级）
- **依赖**: V1 完成后
- **描述**:
  - 为网络层、WBI 签名、`DataState`/`Result`、持久化导入导出、`PlayerController` 状态机等纯逻辑补单元测试（Hypium）
  - 配置测试覆盖率报告
  - 静态分析与代码审查
- **验收标准**: AC-V1-4
- **测试需求**:
  - `programmatic` TR-21.1: 核心纯逻辑测试通过
  - `human-judgement` TR-21.2: 测试用例合理

## [ ] Task 22: 性能优化与多设备打磨
- **优先级**: low
- **依赖**: 各功能任务
- **描述**:
  - 首屏骨架屏/预加载、图片缓存/懒加载、列表虚拟化、内存优化、动画流畅性、折叠屏/平板深度适配
- **验收标准**: AC-A-4, NFR-1
- **测试需求**:
  - `programmatic` TR-22.1: 首屏 < 2s、起播 < 1s
  - `programmatic` TR-22.2: 滚动 ≥ 60fps
  - `human-judgement` TR-22.3: 多设备体验流畅

## [ ] Task 23: 发布准备
- **优先级**: low
- **依赖**: Task 21, Task 22
- **描述**: 应用图标/启动图、签名打包、版本管理、权限声明、隐私政策、全功能回归
- **验收标准**: AC-V1-4
- **测试需求**:
  - `programmatic` TR-23.1: 可正常打包安装
  - `human-judgement` TR-23.2: 图标/启动页精美

## [ ] Task 25: 全局沉浸光感打磨（P3）
- **优先级**: low
- **依赖**: Task 24
- **描述**:
  - 在 P2 底部导航栏沉浸光感基础上，将 barFloatingStyle + ImmersiveMaterial 材质效果扩展至全应用所有页面
  - **兼容回退**：所有沉浸效果在 API/设备不支持（`sdkApiVersion < 26`）时回退为普通组件
  - 顶部状态栏区域沉浸（使用 Navigation/NavDestination 的 barFloatingStyle + systemMaterial 配置沉浸式标题栏）
  - 视频详情页播放器区域沉浸（沉浸式播放体验）
  - 搜索页、动态页、个人页等 Tab 页面底部导航栏材质效果一致性
  - 二级页面（NavDestination）沉浸光感效果与首页一致
  - 深色/浅色模式下沉浸效果均正确
- **验收标准**: AC-A-4
- **测试需求**:
  - `programmatic` TR-25.1: 各页面沉浸光感效果正确
  - `programmatic` TR-25.2: 不支持设备回退为普通组件，功能正常
  - `human-judgement` TR-25.3: 全局沉浸体验一致自然，深/浅色模式均正确
