# 消除 RN 调试入口的 `MarketCoreBridge module not found` WARN — 实现方案

> 状态：待执行 · 2026-08-12 · 已与用户确认（RN 工程加 podspec / 仅注册消除 WARN）

## 背景与根因

DEBUG 构建下通过 RN 调试入口（`Features/RNDev/`，RCTBridge + RCTRootView 加载 Metro bundle）启动外部 RN 工程 `MarketCoreRNApp` 时，JS 侧 `src/services/nativeBridge.ts:35` 的 `const { MarketCoreBridge } = NativeModules` 得到 `undefined`，打出 WARN：

```
WARN [NativeBridge] MarketCoreBridge module not found. Ensure the native module is registered on both platforms.
```

**根因**：`MarketCoreBridge` 是 legacy NativeModule（`RCT_EXPORT_MODULE` 宏 `+load` 自动注册），其实现 `ios/MarketCoreRNApp/MarketCoreBridge.{h,m}`（继承 `RCTEventEmitter <RCTBridgeModule>`，`supportedEvents` 为 `onPlateParams`/`onThemeInfo`）只存在于外部 RN 工程，**从未被编译进 iOSSwiftLogin 的二进制**（Podfile 无指向 RN 工程 ios/ 的 pod，autolinking 只扫 node_modules）。JS 侧只把它当事件源监听、不调用任何方法，所以是 WARN 而非崩溃（有 fallback 兜底）。

**已确认决策**：
1. 在 RN 工程 `ios/` 下新建本地 podspec，iOSSwiftLogin Podfile 以 `:path` 引用——桥源码单一来源保持在 RN 工程，无需拷贝同步。
2. 范围仅注册消除 WARN，不添加任何事件调用点。

**预期结果**：`NativeModules.MarketCoreBridge` 存在，WARN 消失，`ThemeProvider` 正常实例化 `NativeEventEmitter` 监听 `onThemeInfo`（不再走 fallback）。

## 改动文件

### 1. 新建（RN 工程，外部 gitlab 仓库）

`/Users/a1/Documents/gitlab/gyz-h5-marketcore/MarketCoreRNApp/ios/MarketCoreBridge.podspec`：

```ruby
# 本地开发 pod：仅通过 iOSSwiftLogin Podfile 的 :path 引用安装。
# 安装时 CocoaPods 直接读本文件，不校验 s.source（故省略；若日后跑 pod spec lint 再补）。
Pod::Spec.new do |s|
  s.name         = "MarketCoreBridge"
  s.version      = "0.1.0"
  s.summary      = "Native-to-RN event bridge (onPlateParams / onThemeInfo) for MarketCoreRNApp"
  s.homepage     = "https://gitlab.internal/MarketCore"
  s.license      = { :type => "MIT" }
  s.authors      = { "MarketCore" => "dev@internal" }

  # 与 iOSSwiftLogin App 部署目标一致（RN 0.73 最低要求 13.4，16.0 合法）
  s.platforms    = { :ios => "16.0" }

  # 相对本 podspec 目录（ios/）
  s.source_files = "MarketCoreRNApp/MarketCoreBridge.h",
                   "MarketCoreRNApp/MarketCoreBridge.m"

  s.requires_arc = true

  # RCTBridgeModule.h / RCTEventEmitter.h / RCTLog.h 均由 React-Core 提供
  # （header_dir = "React"，<React/*> 尖括号导入可用）；不锁版本，自动解析到
  # use_react_native! 已装的 React-Core 0.73.11，同一 pod 实例不重复编译
  s.dependency "React-Core"
end
```

不写 `s.source`（`:path` 安装不校验 source；`pod spec lint` 才会要求，本方案不跑 lint）。

### 2. 修改

`/Users/a1/Documents/iOSSwiftLogin/iOSLogin/Podfile`，target `'iOSLogin'` 块内（`use_native_modules!` 之后、`use_react_native!` 之前）加：

```ruby
# 桥接源码单一来源：RN 工程 ios/ 下的本地 podspec（消除 NativeModules.MarketCoreBridge === undefined WARN）
# 相对路径按 Podfile 目录（iOSLogin/）解析：../../gitlab/gyz-h5-marketcore/MarketCoreRNApp/ios
pod 'MarketCoreBridge', :path => '../../gitlab/gyz-h5-marketcore/MarketCoreRNApp/ios'
```

用相对路径（与现有 EXTERNAL SOURCES 惯例一致，机器无关）；与 `shell_config['project']['ios']['sourceDir'] = __dir__` hack、`use_react_native!` 均无冲突。不改 RN 工程自身 Podfile。

## 执行步骤

1. 创建 podspec（上述内容）。
2. 修改 Podfile（上述一行）。
3. `cd /Users/a1/Documents/iOSSwiftLogin/iOSLogin && pod install`
   - 预期输出含 `Installing MarketCoreBridge (0.1.0)`；`Podfile.lock` 的 PODS 段新增 `MarketCoreBridge (0.1.0)`（依赖 `React-Core (= 0.73.11)`）、EXTERNAL SOURCES 新增 `:path: "../../gitlab/..."`。
   - 若先 `rm -rf iOSLogin/build/` 则必须重跑 pod install（CLAUDE.md 既有约束，codegen 产物在 install 时重建）。
4. 构建：
   ```bash
   cd /Users/a1/Documents/iOSSwiftLogin/iOSLogin
   xcodebuild -workspace iOSLogin.xcworkspace -scheme iOSLogin \
     -destination 'platform=iOS Simulator,name=iPhone 14' \
     -derivedDataPath build build
   ```
   日志应出现 `CompileC ... MarketCoreBridge.m`。

## 验证

1. **符号验证**（静态确认已编译进 app）：
   ```bash
   nm build/Build/Products/Debug-iphonesimulator/iOSLogin.app/iOSLogin | grep MarketCoreBridge
   # 期望：_OBJC_CLASS_$_MarketCoreBridge
   ```
2. **运行时验证（WARN 消失）**：
   - Metro：`cd /Users/a1/Documents/gitlab/gyz-h5-marketcore/MarketCoreRNApp && npx react-native start`（8081）
   - 安装启动：`xcrun simctl install booted <app路径>` + `xcrun simctl launch booted com.example.iOSLogin`
   - 点右下角 `rnDevButton` → 面板预填 `MarketCoreRNApp`/`localhost`/8081 → 点「启动」
   - 在 Metro/Hermes 控制台确认：**不再出现** `[NativeBridge] MarketCoreBridge module not found...`；**出现** `[Theme] ThemeProvider 挂载，开始监听原生 onThemeInfo 事件（initialTheme=...）`（说明走真实监听而非 fallback）。
3. **回归**：`xcodebuild ... test`（5 条 XCUITest 用例，含 RN 调试入口链路）。

## 风险

- `pod spec lint` 会失败（无 `s.source`）——可接受，本方案只用 `pod install`（`:path` 不校验 source）。
- 相对路径 `../../gitlab/...` 耦合 RN 工程与 iOSSwiftLogin 的兄弟目录布局；迁移后重跑 pod install 即可恢复。
- Release 也编译该模块（无入口 UI，无人调用），与现有 RN 静态库行为一致，可接受。
- 不做任何 Swift/ObjC 业务代码改动，不触碰 AppDelegate 的 window 崩溃防护。