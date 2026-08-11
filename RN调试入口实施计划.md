# iOS 原生工程接入 React Native 调试入口 —— 实施计划

> 状态：已确认方案（待实施）｜日期：2026-08-11

## Context（为什么做这件事）

`iOSSwiftLogin` 是纯 SwiftUI + Combine、**零第三方依赖**的原生 iOS 登录页工程。需求：在**调试/开发期**能直接从该 App 内加载并调试 RN 工程（`MarketCoreRNApp`），免去单独跑 RN 自家壳工程：

- 登录页角落 **DEBUG-only** 浮动按钮 → 弹出调试面板
- 面板输入 **AppName**（默认预填注册名 `MarketCoreRNApp`）+ **端口**（默认 8081）
- 启动后全屏宿主 `RCTRootView`，从 Metro `http://localhost:8081/index.bundle?platform=ios&dev=true` 拉 bundle，`moduleName` = 输入值
- 容器页提供 返回 / Reload / DevMenu；Metro 未启动时 Toast 提示

**已确认决策（用户拍板）**：① AppName 输入值**原样**作 `moduleName`（默认预填 `MarketCoreRNApp`）；② RN 依赖**软链**现成 node_modules（`.claude/settings.local.json` 已预授权 `ln -s` / `pod install *` / `rm -f node_modules`）；③ 入口为**浮动按钮**（`#if DEBUG`，Release 不含）。

**关键事实**（已核实）：
- RN 工程 `/Users/a1/Documents/gitlab/gyz-h5-marketcore/MarketCoreRNApp`：RN **0.73.11**、Hermes 开启、入口 `index.js`、AppRegistry 注册名 `MarketCoreRNApp`、原生依赖 skia/echarts/mmkv/reanimated/screens/safe-area-context/svg/gesture-handler（autolinking 会拉入宿主）
- 本机 Xcode 14.1（14B47b）已验证可构建 RN 0.73.11；CocoaPods 1.16.2 支持 objectVersion 50
- **可复刻参考**：RN 工程内 `NativeShell/ios/`（原生壳嵌 RN 已跑通）。其 Podfile 的关键 workaround：壳工程在仓库子目录时手动跑 `react-native config` 并修正 `project.ios.sourceDir = __dir__`。**额外坑**：iOSSwiftLogin 仓库根无 `ios/` 目录，`react-native config` 的 `project.ios` 为 null，Podfile 需再兜底 `shell_config['project']['ios'] ||= {}`
- Swift `import React` 静态链接可行（React-Core podspec `DEFINES_MODULE=YES`，CocoaPods 生成 modulemap）；RN 0.73.11 真实 API：Reload 用 `RCTTriggerReloadCommandListeners("...")`、DevMenu 用 `RCTShowDevMenuNotification`、Metro ping 用 `RCTBundleURLProvider.isPackagerRunning("localhost:port", scheme: "http")`（同步阻塞，须后台线程）
- `GENERATE_INFOPLIST_FILE=YES` + 物理 `INFOPLIST_FILE` 可合并（物理文件键优先）；ATS 无 `INFOPLIST_KEY_*` 对应项，必须物理文件
- 手写 pbxproj 已核对：`CC…0009`/`BB…0009` 空闲可复用、Features 组 `AA…0008`、iOSLogin 组 `AA…0003`、target 配置 `EE…0003/0004`、下一个空闲 AA ID `0013`、`SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` 已存在

---

## 1. Pods 环境接入

### 1.1 新建仓库根 `package.json`（`/Users/a1/Documents/iOSSwiftLogin/package.json`）

`react-native config` 从 Podfile 目录向上找最近 package.json 作为 project root；autolinking 按依赖枚举原生模块。**只列原生模块（JS-only 的 zustand/dayjs/echarts/@react-navigation 等可不列）**：

```json
{
  "name": "iOSSwiftLogin", "version": "0.0.1", "private": true,
  "dependencies": {
    "react-native": "0.73.11", "react": "18.2.0",
    "@shopify/react-native-skia": "^1.3.1",
    "@wuba/react-native-echarts": "^1.3.1",
    "react-native-gesture-handler": "~2.14.0",
    "react-native-mmkv": "^2.12.2",
    "react-native-reanimated": "~3.6.2",
    "react-native-safe-area-context": "^4.12.0",
    "react-native-screens": "^3.27.0",
    "react-native-svg": "^14.1.0"
  },
  "engines": { "node": ">=18" }
}
```

### 1.2 软链 node_modules（仓库根）

```bash
cd /Users/a1/Documents/iOSSwiftLogin
ln -s /Users/a1/Documents/gitlab/gyz-h5-marketcore/MarketCoreRNApp/node_modules node_modules
ls -l node_modules/react-native/package.json   # 校验
```

### 1.3 新建 `iOSLogin/Podfile`（完整内容，对照 NativeShell + project.ios null 兜底）

```ruby
require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "react-native/scripts/react_native_pods.rb",
    {paths: [process.argv[1]]},
  )', __dir__]).strip

platform :ios, min_ios_version_supported
prepare_react_native_project!

flipper_config = FlipperConfiguration.disabled   # 关 Flipper 避免网络问题

# ⚠️ 仓库根无 ios/ 目录 → react-native config 的 project.ios 为 null，必须兜底。
# 先跑 config，再把 sourceDir 修正为本 Podfile 目录，使 autolinking 的 pod :path
# 与 reactNativePath 都相对本目录解析（CocoaPods 按 Podfile 目录解析相对 path）。
require 'json'
cli_resolve_script = "try {console.log(require('@react-native-community/cli').bin);} catch (e) {console.log(require('react-native/cli').bin);}"
cli_bin = Pod::Executable.execute_command('node', ['-e', cli_resolve_script], true).strip
json_lines = []
IO.popen(['node', cli_bin, 'config']) do |data|
  while (line = data.gets)
    json_lines << line
  end
end
shell_config = JSON.parse(json_lines.join("\n"))
shell_config['project'] ||= {}
shell_config['project']['ios'] ||= {}
shell_config['project']['ios']['sourceDir'] = __dir__

target 'iOSLogin' do
  config = use_native_modules!(shell_config)

  use_react_native!(
    :path => config[:reactNativePath],
    :flipper_configuration => flipper_config,
    :app_path => "#{Pod::Config.instance.installation_root}/.."
  )

  post_install do |installer|
    react_native_post_install(
      installer,
      config[:reactNativePath],
      :mac_catalyst_enabled => false
    )
  end
end
```

### 1.4 pod install 对手写 pbxproj 的影响（安全）

CocoaPods 1.16.2 支持 objectVersion 50。`pod install`（在 `iOSLogin/` 下执行）会向 pbxproj 追加：Pods 组 + Pods.xcodeproj 引用、`Pods-iOSLogin.{debug,release}.xcconfig`、`libPods-iOSLogin.a`、三个 shell script phase（`[CP] Check Pods Manifest.lock` / `Embed Pods Frameworks` / `Copy Pods Resources`）、target 配置加 `baseConfigurationReference`。**UITests target 不在 Podfile，不受影响**。做法：install 前 `git commit` 基线，install 后 review diff，`xcodebuild -workspace iOSLogin.xcworkspace -list` 做闸门，异常 `git checkout project.pbxproj` 重跑（幂等）。

### 1.5 构建命令 `-project` → `-workspace`

pod install 后 `-project` 构建必失败。全部改 `-workspace iOSLogin.xcworkspace -scheme iOSLogin`（scheme 不变、产物路径不变）。受影响：`scripts/ios-reload.sh`、CLAUDE.md、README。**注意**：`rm -rf build/` 会连 `build/generated/ios`（React-Codegen pod 文件）一起删，必须重跑 `pod install`。

---

## 2. ATS 接入

### 2.1 新建物理 `iOSLogin/iOSLogin/Info.plist`（仅 ATS；与 GENERATE_INFOPLIST_FILE=YES 合并，物理键优先）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<false/>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
</dict>
</plist>
```

### 2.2 pbxproj 改动

- `EE…0003`（Debug）与 `EE…0004`（Release）的 buildSettings 各加一行 `INFOPLIST_FILE = iOSLogin/Info.plist;`
- 加文件引用 `BB…0011`（见 §5）；**Info.plist 只进导航器，绝不进 Resources build phase**（否则 "Multiple commands produce"）

---

## 3. 新增 Swift 文件（`iOSLogin/iOSLogin/Features/RNDev/`，全部 `#if DEBUG`）

### 3.1 `RNDevConfig.swift`

`import Foundation`、`import React`。枚举 `RNDevConfig`：
- 常量：`defaultModuleName = "MarketCoreRNApp"`、`defaultBundleRoot = "index"`、`defaultPort = 8081`、UserDefaults keys `rnDev.moduleName` / `rnDev.port`
- `bundleURL(port:bundleRoot:) -> URL?`：`URLComponents` 构造 `http://localhost:<port>/index.bundle?platform=ios&dev=true`
- `isMetroRunning(port:) -> Bool`：`RCTBundleURLProvider.isPackagerRunning("localhost:\(port)", scheme: "http")`（同步阻塞，**调用方须在后台线程**）
- 结构体 `RNLaunchRequest: Identifiable`（`moduleName`、`port`、`bundleRoot = "index"`），sheet → fullScreenCover 传递

### 3.2 `RNDevLauncherView.swift`（调试面板）

复用 `InputField`/`PrimaryButton`/`toast`，全走 `Theme.*`：
- 两个字段：AppName（`InputField(icon: "app.badge.fill", title: "AppName", ...)`，初值 UserDefaults 或默认 `MarketCoreRNApp`）、端口（`keyboardType: .numberPad`，初值 8081）
- 「启动」按钮：校验非空 + 端口 1-65535 → 写入 UserDefaults → `Task.detached` 里 ping Metro（后台线程）→ 成功 `onLaunch(RNLaunchRequest(...))`，失败 Toast「Metro 未启动（localhost:x），请先 npx react-native start」

### 3.3 `RNContainerView.swift`（全屏容器）

要点：**`RCTBridge.delegate` 是 weak，必须外部强持有**；bridge 用 `@StateObject` holder 保证只建一次（SwiftUI struct 会反复重建，不能在 init 直接建）；包一层 UIViewController 供 @react-navigation/native-stack 取 VC 上下文；Reload 用全局命令；返回时 invalidate：

```swift
final class RNBridgeHandle: ObservableObject {
    let bridge: RCTBridge
    let delegate: RNDevBridgeDelegate
    init(request: RNLaunchRequest) {
        delegate = RNDevBridgeDelegate(request: request)
        bridge = RCTBridge(delegate: delegate, launchOptions: nil)
    }
    deinit { bridge.invalidate() }
}

struct RNContainerView: View {
    let request: RNLaunchRequest
    @StateObject private var handle: RNBridgeHandle
    @Environment(\.dismiss) private var dismiss
    // body: VStack { topBar; RNRootViewController(bridge: handle.bridge, moduleName: request.moduleName) }
    // topBar: 返回(accessibilityIdentifier "rnDevBackButton") + 标题(moduleName\nlocalhost:port)
    //        + Reload(RCTTriggerReloadCommandListeners("Reload button"), id "rnDevReloadButton")
    //        + DevMenu(NotificationCenter.post RCTShowDevMenuNotification, id "rnDevMenuButton")
}

struct RNRootViewController: UIViewControllerRepresentable {
    let bridge: RCTBridge; let moduleName: String
    // makeUIViewController: UIViewController + AutoLayout 四边约束嵌入 RCTRootView(bridge:moduleName:initialProperties:nil)
}

final class RNDevBridgeDelegate: NSObject, RCTBridgeDelegate {
    let request: RNLaunchRequest
    func sourceURL(for bridge: RCTBridge) -> URL? { RNDevConfig.bundleURL(port: request.port, bundleRoot: request.bundleRoot) }
}
```

可选：`RCTRootView.loadingView = UIActivityIndicatorView(...)` 显示加载态。

**Plan B（`import React` 失败时）**：改用 bridging header `iOSLogin/iOSLogin/Supporting/RNDev-Bridging-Header.h`（`#import <React/RCTBridge.h>` / `RCTRootView.h` / `RCTBundleURLProvider.h` / `RCTReloadCommand.h` / `RCTDevMenu.h`），EE…0003/0004 加 `SWIFT_OBJC_BRIDGING_HEADER`，Swift 文件去掉 `import React`.

---

## 4. RootView 改动（`iOSLoginApp.swift`）

RootView 承载浮动按钮 + 面板 sheet + 全屏容器 fullScreenCover。用 `pendingLaunch` 在 sheet 的 `onDismiss` 中转投，避免"sheet 未关就 present cover"冲突：

```swift
struct RootView: View {
    #if DEBUG
    @State private var showRNDevPanel = false
    @State private var pendingLaunch: RNLaunchRequest?
    @State private var rnLaunch: RNLaunchRequest?
    #endif
    var body: some View {
        ZStack {
            LoginView()
            #if DEBUG
            rnDevFloatingButton   // 右下角 38×38 圆形 Theme.gradient 按钮，SF Symbol
            #endif                // "chevron.left.forwardslash.chevron.right"
        }
        #if DEBUG
        .sheet(isPresented: $showRNDevPanel, onDismiss: {
            if let p = pendingLaunch { rnLaunch = p; pendingLaunch = nil }
        }) { RNDevLauncherView { req in pendingLaunch = req; showRNDevPanel = false } }
        .fullScreenCover(item: $rnLaunch) { RNContainerView(request: $0) }
        #endif
    }
}
```

浮动按钮：`accessibilityIdentifier("rnDevButton")`、`accessibilityLabel("React Native 调试")`、`.frame(maxWidth:.infinity, maxHeight:.infinity, alignment: .bottomTrailing)` + `.padding(.trailing/.bottom, 16)`。

---

## 5. pbxproj 手改点清单（ID 已核对全空闲）

| 文件 | PBXFileReference | PBXBuildFile |
|---|---|---|
| RNDevConfig.swift | `BB…0009` | `CC…0009` |
| RNDevLauncherView.swift | `BB…000F` | `CC…000D` |
| RNContainerView.swift | `BB…0010` | `CC…000E` |
| Info.plist | `BB…0011`（无 BuildFile） | — |
| RNDev 组 | `AA…0013`（新 PBXGroup） | — |

每个 Swift 文件 4 处（以 RNDevConfig.swift 为例）：
1. **PBXBuildFile** 末尾追加 `CC0000000000000000000009 /* RNDevConfig.swift in Sources */ = {isa = PBXBuildFile; fileRef = BB0000000000000000000009 /* RNDevConfig.swift */; };`
2. **PBXFileReference** 追加 `BB0000000000000000000009 /* RNDevConfig.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RNDevConfig.swift; sourceTree = "<group>"; };`
3. **PBXGroup**：Features 组（`AA…0008`）children 加 `AA…0013 /* RNDev */`；新增组块（children 含上述 3 个 BB，`path = RNDev`）
4. **PBXSourcesBuildPhase**（`DD…0001`）files 加 3 个 `CC…/* ... in Sources */,`

Info.plist 2 处：PBXFileReference（`text.plist.xml`）+ iOSLogin 组（`AA…0003`）children 加 `BB…0011`（不进 build phase）。XCBuildConfiguration 2 处：EE…0003/0004 各加 `INFOPLIST_FILE = iOSLogin/Info.plist;`。

---

## 6. 脚本与文档更新

- **`scripts/ios-reload.sh`**：`deploy()` 内 `-project` → `-workspace iOSLogin.xcworkspace`；watchman trigger 表达式加排除 `["not", ["match", "**/Pods/**", "wholename"]]`；头注释补 workspace 构建与 `rm -rf build/` 后需重跑 `pod install`
- **`.gitignore`**：追加 `Pods/`、`node_modules/`（Podfile.lock 与 xcworkspace 建议提交）
- **`CLAUDE.md`**：构建/测试命令改 workspace；新增「RN 调试入口（DEBUG only）」小节（软链来源与重建、pod install 触发条件、Metro 启动、`Features/RNDev/` 新文件必须 `#if DEBUG`）
- **`README.md`**：补「RN 调试入口」章节（三步使用说明 + Metro 前置）

---

## 7. 实施顺序与验证

**Phase 0 基线**：`git add -A && git commit -m "chore: baseline before RN debug entry"`（保证 pod install 可回滚）

**Phase 1 Pods 环境**：建 package.json → 软链 → 建 Podfile → `pod install`（预期日志含 "Auto-linking React Native modules…"；生成 xcworkspace）→ `git diff project.pbxproj | head` 检查 → `xcodebuild -workspace iOSLogin.xcworkspace -list` 闸门 → 首次 workspace 构建（Intel 本机预计 20-40 分钟，后续增量秒级）：

```bash
xcodebuild -workspace iOSLogin.xcworkspace -scheme iOSLogin \
  -destination 'platform=iOS Simulator,name=iPhone 14' -derivedDataPath build build
```

**Phase 2 ATS**：建物理 Info.plist + pbxproj（INFOPLIST_FILE + BB…0011）→ 构建 → `plutil -p build/Build/Products/Debug-iphonesimulator/iOSLogin.app/Info.plist | grep -E "NSAppTransportSecurity|NSAllowsLocalNetworking"` 验证合并

**Phase 3 UI 代码**：建 3 个 Swift 文件 + 改 RootView + pbxproj（§5）→ 构建通过

**Phase 4 运行验证**：

```bash
cd /Users/a1/Documents/gitlab/gyz-h5-marketcore/MarketCoreRNApp && npx react-native start   # 后台
xcrun simctl bootstatus booted -b
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/iOSLogin.app
xcrun simctl launch booted com.example.iOSLogin
```

手动链路：浮动按钮 `rnDevButton` 可见 → 面板 AppName 预填 `MarketCoreRNApp`、端口 8081 → 启动 → ping 通过 → fullScreenCover 呈现 RN 容器，Metro 日志出现 bundle 请求 → Reload 触发第二次请求 → 返回关闭 cover、bridge invalidate → 停 Metro 再启动 → Toast「Metro 未启动」

**Phase 5 回归 + 脚本**：4 条 XCUITest 全过（`xcodebuild -workspace ... test`）→ 改 ios-reload.sh/.gitignore/CLAUDE.md/README → `bash scripts/ios-reload.sh` 冒烟

---

## 8. 风险清单

| 风险 | 缓解 |
|---|---|
| 首次构建 20-40 分钟（boost/RCT-Folly/hermes/skia） | 一次性全量后增量秒级；固定 `-derivedDataPath build` 复用；避免反复 clean |
| CocoaPods 改手写 pbxproj 出错 | Phase 0 基线 + install 后 review diff + `xcodebuild -list` 闸门 + `git checkout` 重跑（幂等） |
| `react-native config` 解析失败 | 先手动 `node <cli> config` 预检；确认软链生效；Podfile 已兜底 `project.ios` null |
| Redbox（moduleName 不匹配 / 端口错 / Metro 未起） | 预填 `MarketCoreRNApp`；启动前 ping /status 失败弹 Toast 不进入；端口限 1-65535 |
| `import React` umbrella 编译失败 | Plan B bridging header（§3.3） |
| `rm -rf build/` 连删 React-Codegen（build/generated/ios） | 文档注明 wipe build/ 后必须重跑 `pod install` |
| Release 包体膨胀（RN 静态库全量链接，`#if DEBUG` 只裁 UI） | 接受（调试工具定位）；后续可给 RN pods 加 `:configurations => ['Debug']` |
| 软链失效（RN 工程迁移） | CLAUDE.md 记录重建命令；后续可加 `scripts/rn-debug-setup.sh` 集中管理 |
| 真机 localhost 不通 | 文档注明仅模拟器；真机需改 host 为 Mac 局域网 IP（RNDevConfig 预留 host 字段） |
| watchman 误触发（Pods.xcodeproj 命中监听） | ios-reload.sh 表达式加排除 `**/Pods/**` |
| 影响 4 条 XCUITest | 入口 `#if DEBUG` 不自动弹出；独立 identifier 不冲突；Phase 5 回归 |
| bridge 生命周期泄漏 | `@StateObject` holder + `deinit invalidate()` |

## 关键文件

- `iOSLogin/iOSLogin.xcodeproj/project.pbxproj`（CocoaPods 改动 + 3 文件 4 处 + INFOPLIST_FILE）
- `iOSLogin/Podfile`（新建，RN 依赖唯一入口）
- `iOSLogin/iOSLogin/iOSLoginApp.swift`（RootView 编排）
- `iOSLogin/iOSLogin/Features/RNDev/`（RNDevConfig / RNDevLauncherView / RNContainerView）
- 参考：`/Users/a1/Documents/gitlab/gyz-h5-marketcore/MarketCoreRNApp/NativeShell/ios/Podfile`（逐行对照来源）