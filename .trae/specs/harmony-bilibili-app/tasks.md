# 鸿蒙 Bilibili 第三方应用 (OHB) - 实现计划

> **优先级原则**: V1 达标任务（P0）→ 架构达标任务（P1）→ 功能完善任务（P2）→ 质量与打磨（P3）。
> 依赖方向：UI → ViewModel → Repository → Network/Storage。所有任务须遵守 spec.md 的 AP-1~AP-8 架构原则。

---

# P0: V1 达标任务（最高优先级，必须完成）

## [ ] Task 1: 项目基础架构与分层骨架
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

## [ ] Task 2: 网络层 + Result/DataState 状态模型
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

## [ ] Task 3: 数据模型层（V1 必需子集）
- **优先级**: high
- **依赖**: Task 2
- **描述**:
  - **V1 仅实现必需模型**：推荐视频、搜索结果、动态流、视频详情、播放地址、用户信息、登录响应
  - 其余模型（收藏/历史/评论/直播/消息等）在 P2 对应任务中按需补全
  - 使用 ArkTS class/interface + JSON 序列化工具
- **验收标准**: AC-V1-2, AC-V1-3
- **测试需求**:
  - `programmatic` TR-3.1: V1 模型 JSON 反序列化/序列化正确

## [ ] Task 4: 多用户与认证框架（扫码登录优先）
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

## [ ] Task 5: 视频播放器内核抽象与 AVPlayer 实现
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

## [ ] Task 6: 首页推荐流
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

## [ ] Task 7: 搜索功能
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

## [ ] Task 8: 动态流加载（V1：仅加载与跳转）
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

## [ ] Task 9: 视频详情页（V1：播放+基础信息）
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

## [ ] Task 10: V1 集成与可运行性验证
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

## [ ] Task 11: 设置中心与导入导出
- **优先级**: medium
- **依赖**: Task 1
- **描述**:
  - `SettingDefaults` 默认值表集中维护（AP-4）
  - 每设置项独立 key（`@ohos.data.preferences`）
  - **导出**：仅导出值 ≠ 默认值的项 + schemaVersion
  - **导入**：逐项写值，缺失项重置为默认
  - 设置页 UI（播放/外观/搜索/隐私/关于/日志）
  - 导入导出 UI（文件选择/分享）
- **验收标准**: AC-A-2, AC-A-3
- **测试需求**:
  - `programmatic` TR-11.1: 各设置独立存取
  - `programmatic` TR-11.2: 导出仅含非默认项
  - `programmatic` TR-11.3: 导入后恢复、缺失项重置
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

## [ ] Task 13: 视频详情互动（三连/相关/分P/AI总结）
- **优先级**: medium
- **依赖**: Task 9
- **描述**: 三连(点赞/投币/收藏)、相关视频、分P/选集、追番、稍后再看、AI总结、视频详情页完善 UI
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-13.1: 三连操作成功、状态更新
  - `programmatic` TR-13.2: 相关视频/分P 正常
  - `human-judgement` TR-13.3: 详情页完善

## [ ] Task 14: 评论系统
- **优先级**: medium
- **依赖**: Task 9
- **描述**: 评论列表/楼中楼/发表回复/点赞点踩/删除/@；评论组件与 ViewModel
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-14.1: 评论列表分页加载
  - `programmatic` TR-14.2: 发表/回复成功
  - `programmatic` TR-14.3: 点赞/删除正常

## [ ] Task 15: 直播观看
- **优先级**: medium
- **依赖**: Task 2, Task 5
- **描述**: 直播列表/分区、直播流接入 PlayerController、WebSocket 弹幕、互动、屏蔽词
- **验收标准**: AC-F-2
- **测试需求**:
  - `programmatic` TR-15.1: 直播列表加载
  - `programmatic` TR-15.2: 直播流播放
  - `programmatic` TR-15.3: WebSocket 弹幕收发

## [ ] Task 16: 收藏与历史/稍后再看
- **优先级**: medium
- **依赖**: Task 4, Task 9
- **描述**: 收藏夹管理、收藏内视频、排序、稍后再看、历史记录
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-16.1: 收藏夹增删改查
  - `programmatic` TR-16.2: 稍后再看/历史正常

## [ ] Task 17: 用户主页与社交
- **优先级**: medium
- **依赖**: Task 4
- **描述**: UP 主信息、视频/动态/收藏 Tab、关注粉丝列表、关注/拉黑
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-17.1: 用户主页加载
  - `programmatic` TR-17.2: 关注/拉黑操作成功

## [ ] Task 18: 动态详情与发布
- **优先级**: low
- **依赖**: Task 8
- **描述**: 动态详情、点赞/评论/转发、发布动态(图文)、话题广场
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-18.1: 动态详情展示
  - `programmatic` TR-18.2: 互动/发布成功

## [ ] Task 19: 消息与通知
- **优先级**: low
- **依赖**: Task 4
- **描述**: 私信、系统消息、回复我的、@我的、收到的赞、未读计数
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-19.1: 未读计数
  - `programmatic` TR-19.2: 私信收发
  - `programmatic` TR-19.3: 各消息 Tab 正常

## [ ] Task 20: 番剧/追剧与音乐音频
- **优先级**: low
- **依赖**: Task 5
- **描述**: 番剧索引/详情/追番/排行；音乐列表/播放/MediaSession
- **验收标准**: AC-F-3
- **测试需求**:
  - `programmatic` TR-20.1: 番剧模块正常
  - `programmatic` TR-20.2: 音乐播放 + MediaSession

---

# P3: 质量与打磨

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
