# Agents.md

本项目是 HarmonyOS ArkTS 应用（OHB），主模块位于 `entry/`。以下是规范要求。

## 1. 图标

* 必须使用 ArkUI 自带的系统图标，通过 `SymbolGlyph` + `$r('sys.symbol.*')` 引用，例如：

  ```ets
  SymbolGlyph($r('sys.symbol.play_fill'))
  SymbolGlyph($r('sys.symbol.gearshape'))
  ```

* **禁止**使用 emoji、Unicode 特殊字符、乱码符号充当图标（例如 ❌、▶️、★、→ 等）。

* 若系统图标无法满足需求，优先寻找语义最接近的 `sys.symbol.*`；确实缺失时才考虑自定义资源，并在代码中注明原因。

## 2. 路由

* 统一使用 [Route.ets](entry/src/main/ets/framework/Route.ets) 管理路由，不要在页面内自行创建 `NavPathStack` 或使用 router API。

* 新增页面时：

  1. 页面组件的 `build()` **必须以** **`NavDestination`** **作为根组件开头**，否则跳转时直接闪退。示例：

     ```ets
     @Component
     export struct XxxPage {
       build() {
         NavDestination() {
           // 页面内容
         }
         .title('...')
       }
     }
     ```

  2. 在 [Route.ets](entry/src/main/ets/framework/Route.ets) 中：

     * 导入页面组件；

     * 编写 `@Builder` 包装函数（从 `param` 中取出参数传给组件）；

     * 以 `static readonly xxx: RoutePage = new RoutePage(XxxPage.name, wrapBuilder(xxxPageBuilder))` 注册。

  3. 路由参数统一定义在 [RouteParams.ets](entry/src/main/ets/pages/RouteParams.ets)。

* 页面跳转使用 `Route.push(Route.xxx, param)`，返回使用 `Route.pop()`，不要绕过 Route 直接操作 NavPathStack。

## 3. 偏好项（用户设置）

* 所有用户偏好/设置项必须统一定义在 [Pref.ets](entry/src/main/ets/services/storage/Pref.ets)，以 `Pref` 类的 `static readonly PrefItem` 实例形式声明。

* 定义示例（`title` / `desc` 类型需为 `ResourceStr` 以支持资源引用）：

  ```ets
  static readonly defaultQuality: PrefItem<number> = new PrefItem<number>({
    key: 'defaultQuality',
    def: 80,
    title: $r('app.string.pref_default_quality_title') as ResourceStr,
    desc: $r('app.string.pref_default_quality_desc') as ResourceStr,
    onChange: (v) => { /* 值变化时同步到业务 */ }
  })
  ```

* 读取用 `Pref.xxx.get()`，写入用 `Pref.xxx.put(value)`。`PrefItem` 构造时会自动注册到 `Pref.items`（设置中心列表）。

* 敏感数据（token 等）不要放进 Pref，使用 [SecureStorage.ets](entry/src/main/ets/services/storage/SecureStorage.ets)。

## 4. 文案与资源

* 用户可见的文案（标题、描述、按钮文本、 toast 提示等）**禁止硬编码字符串**，必须使用资源值 `$r('app.string.xxx')`。

* 新增字段时，必须同时在两处生成对应资源，保证中英文同步：

  * 英文（默认）：[string.json](entry/src/main/resources/base/element/string.json)

  * 中文：[string.json](entry/src/main/resources/zh_CN/element/string.json)

* 命名采用小写下划线，按模块加前缀，例如 `settings_`、`pref_`、`login_`、`video_`。

* 示例：

  ```json
  // base/element/string.json
  { "name": "settings_dark_mode_title", "value": "Dark mode" }
  // zh_CN/element/string.json
  { "name": "settings_dark_mode_title", "value": "深色模式" }
  ```

## 5. 日志

* 统一直接使用系统 `hilog`（`@kit.PerformanceAnalysisKit`）打印日志，**禁止**封装 hilog，也**禁止**使用已封装的 [Logger.ets](entry/src/main/ets/common/utils/Logger.ets)。

* 每个使用日志的文件，TAG 统一定义在**文件最下方**：`const TAG = XXX.name ?? 'XXX'`（`XXX` 为当前文件的主类/组件名）。

* 示例：

  ```ets
  import { hilog } from '@kit.PerformanceAnalysisKit';

  @Component
  export struct XxxPage {
    aboutToAppear(): void {
      hilog.info(0x0000, TAG, 'onAppear');
    }
  }

  // TAG 固定写在文件最下方
  const TAG = XxxPage.name ?? 'XxxPage';
  ```

## 6. 参考项目 PiliPlus

* `./PiliPlus` 是 [PiliPlus](https://github.com/dev4harmony/PiliPlus)（Flutter 版 B 站第三方客户端）的 **git 子模块**，作为本项目的参考实现。它是**只读参考**：不要修改其中代码，也不要将其纳入 OHB 构建。

* 当需求未说明实现细节、或不确定某个 B 站接口如何调用（参数、签名、风控头）时，**优先查阅 PiliPlus 源码**寻找对应实现，再映射到 ArkTS：
  * `lib/http/`：各业务模块的请求层（api.dart 为接口 URL 清单，各业务文件含完整请求参数与请求头）
  * `lib/common/constants.dart`：appkey/appsec、UA、statistics 等常量
  * `lib/utils/`：签名（AppSign/WbiSign）、账号体系、buvid 生成等工具

* 典型场景：App 通道签名参数、WBI 签名、-352 风控（buvid 头 / build / statistics 参数）、弹幕 protobuf 接口字段、画质列表解析等，均可直接对照 PiliPlus 的请求实现。

* 子模块常用命令：`git submodule update --init`（克隆后初始化）、`git submodule update --remote PiliPlus`（更新到上游最新）。

## 附：忽略目录

`.trae/`、`.workbuddy/`、`.codegenie/` 为本地工具目录，已加入 `.gitignore`，不要将其中的文件提交或纳入构建。
