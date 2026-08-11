# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

iOS 登录页原生实现：将根目录 `index.html`（高保真交互原型）一比一落地为 SwiftUI App。纯 SwiftUI + Combine，**无任何第三方依赖**。配套文档：`README.md`（设计规范，含 HTML→SwiftUI 映射表）、`iOS实现计划.md`（实施记录）。任何 UI 改动请先对照 `README.md` 第 2 章设计令牌映射。

## 构建与测试

```bash
cd iOSLogin
# 构建（模拟器，产物输出到 build/）
xcodebuild -project iOSLogin.xcodeproj -scheme iOSLogin \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  -derivedDataPath build build
# 运行 XCUITest（4 条验收用例）
xcodebuild -project iOSLogin.xcodeproj -scheme iOSLogin \
  -destination 'platform=iOS Simulator,name=iPhone 14' test
# 安装并启动
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/iOSLogin.app
xcrun simctl launch booted com.example.iOSLogin
# 模拟器"类热更新"（watchman 监听 .swift / pbxproj / xcscheme，保存即自动构建+安装+重启）
bash scripts/ios-reload.sh          # 交互模式：首次部署 + 注册监听；Ctrl+C 停止并清理
bash scripts/ios-reload.sh deploy   # watchman 回调入口（单次部署，一般不自调用）
```

约束：部署目标 iOS 16.0、Swift 5.0、仅 iPhone、bundle id `com.example.iOSLogin`。工程用 Xcode 14.1，避免使用 Xcode 15+ API（`#Preview` 宏、`ContentUnavailableView` 等）。热更新方案细节见 `iOS模拟器热更新方案.md`。

## 架构

MVVM 分层，`iOSLogin/iOSLogin/` 下：

- **`DesignSystem/Theme.swift`** — 全部设计令牌（颜色/圆角/阴影/间距/字号/动效时长），与 `index.html` 的 CSS 变量一一对应。**禁止在视图代码中硬编码视觉值，一律走 Theme**。
- **`Components/Components.swift`** — 复用组件：`InputField`（聚焦光环/错误态/清空/密码可见）、`PrimaryButton`（`ButtonState` 四态状态机）、`CustomCheckbox`、`TabSlider`、`Toast`（ViewModifier）、`ShakeEffect`。新增组件优先放这里。
- **`Features/Login/`** — `LoginViewModel`（@MainActor ObservableObject，集中式状态机）+ `LoginView`（根视图，编排全局层）+ `OTPField` + `SuccessOverlay`。
- **`Features/Register/`、`Features/ForgotPassword/`** — 注册页（stub）、忘记密码底部抽屉。

`LoginView` 是全局层编排中心：自身承载注册页 slide-in 过渡、忘记密码弹窗、成功遮罩、Toast，共享同一个 `LoginViewModel`。`iOSLoginApp.swift` 的 `RootView` 仅放 `LoginView`。

## 关键实现约定（涉及多文件，改动前必读）

- **校验规则集中在 `Validator` enum**（`LoginViewModel.swift` 顶部）：独立于 ViewModel，供登录/注册/忘记密码复用。这是刻意设计——`@MainActor` 类的静态方法在非主 actor 上下文调用会编译报错，勿改回类内。
- **表单状态集中在 ViewModel**：字段值、错误、`ButtonState`、倒计时的启用一律集约在 `LoginViewModel`，视图侧只放 UIKit 无关的 UI 状态（`@State` 用于 shake 计数等）。`onChange(of:)` 统一调 `recomputeButton()` 做按钮启停。
- **倒计时用 Combine `Timer.publish`**，不用 `Timer.scheduledTimer`（后者闭包会触发 Sendable 并发捕获编译错误）；`deinit`/`onDisappear` 清理。
- **登录/注册/发送重置均为模拟流程**：`Task.sleep` 占位（登录 1.4s→success 400ms→遮罩 2.5s）。接真实接口时替换这些占位点，`Validator` 与状态机保留。
- **OTP 用单 TextField + 6 视觉格子**（透明文字层叠，`textContentType(.oneTimeCode)` 支持短信填充），不是 6 个独立输入框。发送验证码按钮是标题行右侧的小尺寸描边胶囊（`sendCodeButton`），与 OTP 格子分行布局，不挤同一行。
- **Xcode Preview 用 `PreviewProvider`**（见 `LoginView` 底部 `LoginView_Previews`），不要写 `#Preview` 宏（Xcode 15+ API，与工程约束冲突）。
- **页面切换不用 NavigationStack**：注册页用 ZStack + offset/fade 自绘过渡；返回按钮是自定义左上角按钮（`accessibilityLabel("返回登录")`）。
- **App 强制浅色**：`RootView` 上有 `preferredColorScheme(.light)`，接深色模式时移除并补深色令牌。
- **工程文件手写**：`project.pbxproj` 为手写（xcodegen 不可用，objectVersion 50），编辑需保证括号平衡；共享 scheme 在 `xcshareddata/xcschemes`。

## 测试

`iOSLoginUITests` 通过 **accessibility 树**验证（不依赖像素渲染——本机 Intel 模拟器无图形会话下截图全黑）。新增 UI 时给关键元素加 `accessibilityIdentifier`/`accessibilityLabel`（如 `agreementCheckbox`、`otpInput`），测试按文案或 identifier 定位。4 条用例覆盖：元素齐全、密码登录全流程、验证码链路、注册页导航。

## 已知边界

- 注册页是 stub（仅入口跳转示意），协议/隐私政策内容为占位（点击仅弹 Toast）。
- 无第三方登录、无网络层、无单元测试（`Validator`/`LoginViewModel` 单测为后续迭代项）。
- 深色模式未做。