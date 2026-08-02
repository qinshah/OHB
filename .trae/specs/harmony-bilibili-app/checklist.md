# 鸿蒙 Bilibili 第三方应用 (OHB) - 验证清单

> 优先级：V1 达标（P0）> 架构达标（P1）> 功能完善（P2）> 质量打磨（P3）。

## P0: V1 达标验证（最高优先级）

### 项目可运行性
- [ ] Checkpoint 1: 项目全量编译 0 报错（ArkTS 严格模式）
- [ ] Checkpoint 2: 应用可正常安装并启动，无崩溃
- [ ] Checkpoint 3: 主框架导航（首页/搜索/动态/我的 Tab）可切换
- [ ] Checkpoint 4: 端到端流程可用（登录→首页→搜索→动态→视频播放）

### 登录与多用户
- [ ] Checkpoint 5: 扫码登录二维码正确生成并显示
- [ ] Checkpoint 6: 轮询状态机正确（等待→已扫描→已确认→成功）
- [ ] Checkpoint 7: 登录成功后 Token 与用户信息正确存储
- [ ] Checkpoint 8: 登录态持久化，重启应用后自动登录
- [ ] Checkpoint 9: 多账户切换框架可用，账户数据空间正确隔离
- [ ] Checkpoint 10: 凭证（Token/Cookie）加密存储，不落明文
- [ ] Checkpoint 11: 退出登录正常清除认证信息
- [ ] Checkpoint 12: 登录页 UI 美观、交互流畅

### 首页/搜索/动态加载与跳转
- [ ] Checkpoint 13: 首页推荐视频列表正确加载
- [ ] Checkpoint 14: 下拉刷新、上拉分页正常
- [ ] Checkpoint 15: 黑名单/关键词过滤生效
- [ ] Checkpoint 16: 搜索建议实时返回
- [ ] Checkpoint 17: 分类搜索结果正确（视频/直播/用户/番剧/文章）
- [ ] Checkpoint 18: 搜索历史正确存取
- [ ] Checkpoint 19: 动态流正确加载、可分页
- [ ] Checkpoint 20: 首页/搜索/动态中视频项可跳转视频页

### 视频页基础播放
- [ ] Checkpoint 21: 视频流地址正确获取并播放
- [ ] Checkpoint 22: 播放/暂停正常
- [ ] Checkpoint 23: 全屏切换正常，横竖屏适配
- [ ] Checkpoint 24: 进度跳转（seek）正常
- [ ] Checkpoint 25: 音量调节正常
- [ ] Checkpoint 26: 亮度调节正常
- [ ] Checkpoint 27: 视频详情基础信息（标题/简介/UP主）正确展示

## P1: 架构达标验证

### 分层与状态模型
- [ ] Checkpoint 28: 目录分层清晰（UI/ViewModel/Repository/Network/Storage），依赖单向（AP-1）
- [ ] Checkpoint 29: `Result<T,E>` 请求结果与 `DataState<T>` UI 状态分离（AP-2）
- [ ] Checkpoint 30: `DataState` 状态机流转正确（Idle/Loading/Refreshing/Data/Error/Empty）
- [ ] Checkpoint 31: 统一 `AppError` 错误模型，错误信息不散落
- [ ] Checkpoint 32: 未直接照搬 PiliPlus 的 LoadingState 三态设计

### 播放器内核可切换
- [ ] Checkpoint 33: `IPlayerEngine` 接口抽象完整（play/pause/seek/音量/亮度/倍速/清晰度/状态流）
- [ ] Checkpoint 34: `AvPlayerEngine` 基于 AVPlayer 正确实现
- [ ] Checkpoint 35: `PlayerController` 统一控制器正常工作
- [ ] Checkpoint 36: 内核可替换——新增 mpv/mdk 仅需实现接口，UI/Controller 无需改动

### 设置导入导出
- [ ] Checkpoint 37: `SettingDefaults` 默认值表集中维护
- [ ] Checkpoint 38: 每设置项独立 key，修改只写对应 key
- [ ] Checkpoint 39: 导出仅含值 ≠ 默认值的项 + schemaVersion
- [ ] Checkpoint 40: 导入逐项写值，缺失项重置为默认值
- [ ] Checkpoint 41: 导入导出 UI（文件选择/分享）可用

### 多设备适配
- [ ] Checkpoint 42: 基于 Navigation 单栏/分栏自动切换（手机单栏、平板/折叠屏分栏）
- [ ] Checkpoint 43: 使用栅格/断点，一次开发适配手机/平板/折叠屏
- [ ] Checkpoint 44: 多窗口/自由窗口/小窗模式下播放器适配正常
- [ ] Checkpoint 45: 资源使用 fp/vp，无硬编码尺寸
- [ ] Checkpoint 46: 深色模式与动态取色正常

### 网络与持久化
- [ ] Checkpoint 47: HTTP 客户端统一封装，GET/POST 正常
- [ ] Checkpoint 48: WBI 签名输出与参考算法一致
- [ ] Checkpoint 49: Cookie 持久化存取正常
- [ ] Checkpoint 50: 请求拦截（token/UA/错误转换/日志）正常

## P2: 功能完善验证（对齐 PiliPlus）

### 播放器完善
- [ ] Checkpoint 51: 多清晰度切换正常
- [ ] Checkpoint 52: 倍速播放（0.5x-4x）正常
- [ ] Checkpoint 53: 画中画（PiP）正常
- [ ] Checkpoint 54: 播放进度记忆与恢复正常
- [ ] Checkpoint 55: 自动连播下一集正常
- [ ] Checkpoint 56: 字幕支持正常

### 弹幕
- [ ] Checkpoint 57: 集成 `@ohos/danmakuflamemaster`，弹幕正确渲染
- [ ] Checkpoint 58: 弹幕发送功能正常，发送后立即显示
- [ ] Checkpoint 59: 弹幕样式配置（颜色/字号/位置）生效
- [ ] Checkpoint 60: 弹幕屏蔽（关键词/正则/用户）规则生效
- [ ] Checkpoint 61: 弹幕密度调节、显隐开关正常
- [ ] Checkpoint 62: 弹幕渲染流畅 ≥ 60fps，不阻塞播放

### 视频详情互动
- [ ] Checkpoint 63: 三连（点赞/投币/收藏）操作成功，状态实时更新
- [ ] Checkpoint 64: 一键三连功能正常
- [ ] Checkpoint 65: 相关视频列表正确
- [ ] Checkpoint 66: 分P/选集切换正常
- [ ] Checkpoint 67: 稍后再看添加/移除正常
- [ ] Checkpoint 68: AI总结功能正常

### 评论
- [ ] Checkpoint 69: 评论列表分页加载
- [ ] Checkpoint 70: 楼中楼正确展开
- [ ] Checkpoint 71: 发表评论/回复成功并显示
- [ ] Checkpoint 72: 评论点赞/点踩/删除正常
- [ ] Checkpoint 73: @功能正常

### 直播
- [ ] Checkpoint 74: 直播列表加载，分区筛选正常
- [ ] Checkpoint 75: 直播流正常播放（经 PlayerController）
- [ ] Checkpoint 76: WebSocket 弹幕实时收发
- [ ] Checkpoint 77: 直播间互动（关注/分享）正常
- [ ] Checkpoint 78: 直播间屏蔽词管理正常

### 收藏与历史
- [ ] Checkpoint 79: 收藏夹列表加载
- [ ] Checkpoint 80: 创建/编辑/删除/排序收藏夹正常
- [ ] Checkpoint 81: 收藏内视频列表正确
- [ ] Checkpoint 82: 稍后再看添加/移除/清空正常
- [ ] Checkpoint 83: 历史记录加载与删除正常

### 用户主页与社交
- [ ] Checkpoint 84: UP 主主页信息正确（头像/昵称/等级/统计）
- [ ] Checkpoint 85: 视频/动态/收藏 Tab 切换正常
- [ ] Checkpoint 86: 关注/取消关注、拉黑/取消拉黑正常
- [ ] Checkpoint 87: 关注/粉丝列表正确

### 动态详情与发布
- [ ] Checkpoint 88: 动态详情正确展示
- [ ] Checkpoint 89: 动态点赞/评论/转发成功
- [ ] Checkpoint 90: 发布动态（图文）成功

### 消息与通知
- [ ] Checkpoint 91: 未读消息计数正确
- [ ] Checkpoint 92: 私信列表与收发正常
- [ ] Checkpoint 93: 系统消息/回复我的/@我的/收到的赞正常

### 番剧与音乐
- [ ] Checkpoint 94: 番剧索引/详情/追番/排行正常
- [ ] Checkpoint 95: 音乐列表加载、播放正常
- [ ] Checkpoint 96: MediaSession（锁屏控制）正常

### 沉浸光感（底部导航栏）
- [x] Checkpoint 97: 底部导航栏沉浸光感效果正确（barFloatingStyle + systemMaterial/ImmersiveMaterial 渲染）
- [x] Checkpoint 98: 不支持沉浸光感的设备/API（sdkApiVersion < 26）回退为普通不透明导航栏，功能正常
- [ ] Checkpoint 99: 底部 Tab 内容视觉效果自然

## P3: 质量与打磨验证

### 单元测试（V1 降级，后续补充）
- [ ] Checkpoint 100: 网络层/WBI 签名单元测试通过
- [ ] Checkpoint 101: `Result`/`DataState`/`AppError` 状态机测试通过
- [ ] Checkpoint 102: 持久化导入导出逻辑测试通过
- [ ] Checkpoint 103: `PlayerController` 状态机测试通过
- [ ] Checkpoint 104: 测试用例设计合理

### 性能
- [ ] Checkpoint 105: 首页首屏加载 < 2s（正常网络）
- [ ] Checkpoint 106: 视频起播 < 1s
- [ ] Checkpoint 107: 列表/弹幕滚动 ≥ 60fps
- [ ] Checkpoint 108: 内存占用合理，无泄漏

### 多设备深度适配
- [ ] Checkpoint 109: 手机设备显示与操作正常
- [ ] Checkpoint 110: 平板大屏适配正常（分栏/瀑布流）
- [ ] Checkpoint 111: 折叠屏折叠/展开切换正常
- [ ] Checkpoint 112: 多窗口模式正常

### UI/UX
- [ ] Checkpoint 113: 整体 UI 符合 HarmonyOS Design
- [ ] Checkpoint 114: 深色模式所有页面正常
- [ ] Checkpoint 115: 转场动画流畅
- [ ] Checkpoint 116: 字体大小设置实时生效

### 代码质量
- [ ] Checkpoint 117: ArkTS 严格模式无 lint 错误
- [ ] Checkpoint 118: 模块分层清晰、职责单一
- [ ] Checkpoint 119: 关键纯逻辑有单元测试

### 安全
- [ ] Checkpoint 120: 用户凭证加密存储
- [ ] Checkpoint 121: HTTPS 加密传输
- [ ] Checkpoint 122: 敏感操作需认证

### 发布准备
- [ ] Checkpoint 123: 应用图标/启动图正确
- [ ] Checkpoint 124: 签名打包正常
- [ ] Checkpoint 125: 版本号正确
- [ ] Checkpoint 126: 权限声明完整
- [ ] Checkpoint 127: 全功能回归通过

### 沉浸光感（全局打磨）
- [ ] Checkpoint 128: 各页面沉浸光感效果正确（barFloatingStyle + systemMaterial 一致性）
- [ ] Checkpoint 129: 不支持设备回退为普通组件，功能正常
- [ ] Checkpoint 130: 深色/浅色模式下沉浸效果均正确
