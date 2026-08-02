# OHB 项目长期备忘

## 项目概况
- OHB：鸿蒙原生第三方 Bilibili 客户端（HarmonyOS NEXT，Stage 模型，ArkTS 严格模式）
- 需求文档：`.trae/specs/harmony-bilibili-app/`（spec.md / tasks.md / checklist.md）
- 参考项目：PiliPlus（Flutter，仅作 API/业务流程参考，不照搬架构）
- 构建：`/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --no-daemon -p buildMode=debug`
- SDK：`~/Library/OpenHarmony/Sdk`（14/20/23/26.0.0）；local.properties 的 sdk.dir 指向此处
- build-profile：compileSdkVersion/targetSdkVersion 改为 "26.0.0"（API 26+ 必须用字符串），compatibleSdkVersion 保持 14（数字）

## 架构基线（AP-1~AP-7）
- 分层：pages → viewmodel(@Observed) → data/repository → network(BiliApi/HttpClient) → services
- 状态：Result<T>(Ok/Err) + DataState<T>(Idle/Loading/Refreshing/Data/Error/Empty) + AppError，禁用 PiliPlus 三态
- 播放：IPlayerEngine（可换 mpv/mdk）→ PlayerController → UI；默认 AvPlayerEngine
- 持久化：PrefsStorage 独立 key；SecureStorage=Asset Store 存凭证；CookieManager 按 mid 命名空间
- UI：Navigation(NavPathStack+pageMap)+Tabs(首页/搜索/动态/我的)；深浅色走 resources dark/；品牌色 #FB7299
- 沉浸光感：通过 `Tabs.barFloatingStyle({ barBottomMargin: 0, systemMaterial: new uiMaterial.ImmersiveMaterial({style: THICK, interactive: true}) })` 设置浮动沉浸材质；配合 `barOverlap(true)` + `barBackgroundColor(Color.Transparent)` 让内容透过半透明材质显现；ImmersiveHelper 用 `deviceInfo.sdkApiVersion >= 26` 检测；两套 Tabs Builder（`buildImmersiveTabs`/`buildNormalTabs`）通过 `if/else` 切换；**不需要** setWindowLayoutFullScreen/expandSafeArea
- **关键限制**：`@kit.UIDesignKit`（HDS 组件 HdsTabs/hdsMaterial）仅在 HarmonyOS SDK 可用，OpenHarmony SDK 无此 kit；当前项目 runtimeOS="OpenHarmony"，故使用 `@kit.ArkUI` 的 `uiMaterial` API（since 26.0.0）
- **踩坑**：`.systemMaterial()` 在 CommonMethod 上接受 `SystemUiMaterial`（非 ImmersiveMaterial），直接调用类型不匹配且无效；正确方式是通过 `FloatingTabBarStyle.systemMaterial` 字段传入 `ImmersiveMaterial`

## ArkTS 踩坑（本项目实测）
- interface 内联对象类型（`a?: { b?: string }`）报 10605040，必须拆成独立 interface
- `parsed.data ?? {}` 空对象字面量报 10605038，用 `new EmptyData()` 占位
- `getHostContext()` 返回 `Context | undefined`，须判空
- API 20 SDK：asset 用 addSync/querySync/removeSync；AVPlayer bufferingUpdate 回调签名是 `(infoType: BufferingInfoType, value: number)`；AVPlayer setSpeed 只接受 PlaybackSpeed 枚举档位
- @State 属性名不得与 CustomComponent 基类冲突（tabIndex/width/opacity 等）
- Column 无 alignContent，用 height(100%)+justifyContent(FlexAlign.End)

## B站 API 要点（PiliPlus 提取）
- WBI：nav 取 wbi_img，mixinKeyEncTab 32 位重排，wts+w_rid=md5(query+mixinKey)，按天缓存
- TV 扫码：POST /x/passport-tv-login/qrcode/auth_code → poll（86039等/86090扫/86038过期/0成），AppSign(appkey dfca71928277209b)
- 推荐：/x/web-interface/wbi/index/top/feed/rcmd (WBI)；播放：/x/player/wbi/playurl (V1 fnval=1)
- Cookie 关键字段：SESSDATA / bili_jct(csrf) / DedeUserID / access_key(App 端 token)
