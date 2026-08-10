# iOS 登录页 · 原生实现计划

> 依据 `index.html` 高保真原型，落地为 SwiftUI 原生 iOS 应用，按阶段实施并在 iOS 模拟器验证。
> 本文档记录计划、实施结果与验收情况，供开发团队与后续迭代参考。

---

## 1. 项目概述

| 项目 | 内容 |
|---|---|
| 目标 | 将 `index.html` 登录页原型一比一实现为原生 iOS App |
| 技术栈 | SwiftUI（iOS 16+）、Combine、Xcode 14.1 |
| 基准设备 | iPhone 14（iOS 16.1 模拟器，390×844 pt） |
| 交付物 | `iOSLogin/` 完整 Xcode 工程 + 本计划文档 |
| 原型参考 | `index.html`（高中保真交互原型）、`README.md`（设计规范） |

**功能范围**：密码登录、验证码登录、注册页（stub）、忘记密码弹窗、登录成功动效、Toast、表单校验、协议勾选。

## 2. 目录结构

```
iOSLogin/
├── iOSLogin.xcodeproj/            # Xcode 工程（含共享 Scheme）
├── iOSLogin/
│   ├── iOSLoginApp.swift          # App 入口 + RootView
│   ├── DesignSystem/
│   │   └── Theme.swift            # 设计令牌（颜色/字体/圆角/阴影/间距）
│   ├── Components/
│   │   └── Components.swift       # InputField/PrimaryButton/CustomCheckbox/TabSlider/Toast/Shake
│   ├── Features/
│   │   ├── Login/
│   │   │   ├── LoginView.swift        # 登录主视图（双 Tab + 表单 + 全局层编排）
│   │   │   ├── LoginViewModel.swift   # 状态机（校验/倒计时/登录流程）
│   │   │   ├── OTPField.swift         # 6 位验证码输入
│   │   │   └── SuccessOverlay.swift   # 登录成功全屏遮罩
│   │   ├── Register/
│   │   │   └── RegisterView.swift     # 注册页（stub）
│   │   └── ForgotPassword/
│   │       └── ForgotPasswordSheet.swift  # 忘记密码底部弹窗
│   └── Assets.xcassets/           # AppIcon / AccentColor
└── iOSLoginUITests/
    └── iOSLoginUITests.swift      # XCUITest 验收测试（4 条用例）
```

## 3. 分阶段实施计划与完成情况

### 阶段 0：工程脚手架 ✅
- **计划**：手动创建 `project.pbxproj`、共享 Scheme、Asset Catalog、最小 App 入口；构建 + 模拟器启动验证。
- **实施**：Xcode 14.1 环境（xcodegen 不可用，手写 pbxproj，objectVersion 50）；部署目标 iOS 16.0；`GENERATE_INFOPLIST_FILE` 免维护 Info.plist。
- **验证**：`xcodebuild -list` 识别 target/scheme；`BUILD SUCCEEDED`；`simctl install + launch` 成功（PID 启动）。

### 阶段 1：设计系统与复用组件 ✅
- **计划**：`Theme.swift` 设计令牌（对应 README 映射表）+ `Components.swift` 组件层。
- **实施**：
  - `Theme`：品牌渐变 `#5B7CFF→#8A5CFF`、中性色、成功/错误色、圆角刻度、阴影、间距、字号。
  - `InputField`：前缀图标、focus 光环（双层 overlay）、错误态、清空按钮、密码可见切换、maxLength 清洗、onBlur 回调。
  - `PrimaryButton`：`enabled/disabled/loading/success` 状态机 + 按压 scale。
  - `CustomCheckbox`：渐变勾选 + 对勾缩放动画。
  - `TabSlider`：胶囊指示器 spring 滑动。
  - `Toast`：顶部胶囊三变体，2.2s 自动消失（ViewModifier）。
  - `ShakeEffect`：GeometryEffect 抖动。
- **修正**：`Color.error` 无成员（改 `Color(hex:)`）；`Text.letterSpacing` 为 iOS16+ API（移除）；`#Preview` 为 Xcode15 API（移除）。

### 阶段 2：登录页静态 UI ✅
- **计划**：头部 + 双 Tab + 密码/验证码表单 + 协议 + 主按钮 + 入口。
- **实施**：`LoginView` 采用 ScrollView 可滚动布局；双 Tab 通过 `LoginMode` 枚举 + ZStack 双向切换（fade 过渡）；表单字段用 InputField 组合；协议勾选联动按钮；底部忘记密码/注册入口。
- **验证**：`testLoginPageElementsExist` 通过（元素齐全、按钮初始禁用）。

### 阶段 3：表单校验与输入交互 ✅
- **计划**：实时清洗、blur 校验、错误抖动、按钮启停。
- **实施**：
  - 校验规则提取为独立 `enum Validator`（非 actor，供登录/注册/忘记密码复用）——避免 `@MainActor` 类静态方法在非主 actor 上下文调用报错。
  - 失焦校验失败自动触发 `ShakeEffect` 抖动；输入变化即时清除错误。
  - 手机号仅数字限 11 位、密码限 20 位清洗。
  - 按钮启停集中式 `recomputeButton()`。
- **验证**：`testPasswordLoginFlow` 通过（未勾选协议按钮禁用 → 勾选后启用）。

### 阶段 4：验证码链路（倒计时 + OTP）✅
- **计划**：发送验证码前置校验、60s 倒计时、OTP 6 位输入。
- **实施**：
  - 倒计时用 Combine `Timer.publish`（替代 `Timer.scheduledTimer`，规避并发捕获检查；`onDisappear`/deinit 自动清理）。
  - `OTPField`：单透明 TextField（品牌色 caret）+ 6 视觉格，`textContentType(.oneTimeCode)` 支持 iOS 短信填充；数字过滤、粘贴自动分发。
- **验证**：`testSMSCodeFlow` 通过（倒计时按钮文字出现、OTP 输入后按钮启用）。

### 阶段 5：流程编排（登录/注册/弹窗/Toast/成功遮罩）✅
- **计划**：登录状态机、注册页过渡、忘记密码弹窗、Toast。
- **实施**：
  - 登录：loading 1.4s → success 400ms → 全屏 `SuccessOverlay`（渐变 + 对勾 trim 描边动画 + 文案上浮）→ 2.5s 后重置表单。
  - 注册页：slide-in 覆盖 + 返回；手机号/密码/确认密码校验。
  - 忘记密码：底部抽屉（遮罩/关闭/Esc 可关），提交 Toast。
- **验证**：`testRegisterNavigation` 通过；登录成功遮罩在密码流程测试中断言。

### 阶段 6：模拟器启动验收 + 计划文档 ✅
- **实施**：
  - 最终版构建安装到 iPhone 14 模拟器并启动（`simctl launch` PID 正常）。
  - 增加 XCUITest target（手写 pbxproj 的 UITests target + 共享 Scheme TestAction），通过 accessibility 树验证 UI——因本机 Intel 模拟器在无图形会话下截图全黑，改用 XCUITest 做真实交互验收。
  - 编写本文档。

## 4. 设计系统映射（HTML → SwiftUI）

| HTML 令牌 | SwiftUI | 位置 |
|---|---|---|
| `--c-primary-500` `#5B7CFF` | `Theme.primary` | Theme.swift |
| `--c-gradient` | `Theme.gradient`（`LinearGradient`） | Theme.swift |
| `--c-bg` `#F7F8FC` | `Theme.bg` | Theme.swift |
| `--r-input` 14 | `Theme.radiusInput` | Theme.swift |
| `--shadow-btn` | `Theme.shadowButton` | Theme.swift |
| `--dur-base` 250ms | `Theme.durBase` | Theme.swift |
| `.input-box:focus-within` 光环 | InputField 双层 overlay stroke | Components.swift |
| `.btn-login` 状态机 | `PrimaryButton` + `ButtonState` | Components.swift |
| OTP 视觉格 | `OTPField` 6 格 + 透明输入层 | OTPField.swift |

完整色值/字体/圆角/阴影对照见根目录 `README.md` 第 2 章。

## 5. 测试与验收

### 5.1 XCUITest 用例（全部通过 ✅）

| 用例 | 覆盖 |
|---|---|
| `testLoginPageElementsExist` | 登录页元素齐全、登录按钮初始禁用 |
| `testPasswordLoginFlow` | 密码输入 → 协议勾选联动 → 登录成功遮罩 |
| `testSMSCodeFlow` | 验证码 Tab、手机号、倒计时、OTP、按钮启用 |
| `testRegisterNavigation` | 注册页滑入/返回 |

运行方式：
```bash
cd iOSLogin
xcodebuild -project iOSLogin.xcodeproj -scheme iOSLogin \
  -destination 'platform=iOS Simulator,name=iPhone 14' test
```

### 5.2 构建与运行
```bash
cd iOSLogin
# 构建（模拟器）
xcodebuild -project iOSLogin.xcodeproj -scheme iOSLogin \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  -derivedDataPath build build
# 安装并启动
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/iOSLogin.app
xcrun simctl launch booted com.example.iOSLogin
```
也可直接用 Xcode 打开 `iOSLogin.xcodeproj` 按 ⌘R 运行。

## 6. 实施中解决的问题（供参考）

| 问题 | 根因 | 方案 |
|---|---|---|
| `Color.error` 编译错误 | SwiftUI `Color` 无 `error` 成员 | 用 `Color(hex: 0xFF3B30)` |
| `#Preview` 编译错误 | Xcode 15 宏，本机 Xcode 14 | 移除 |
| `letterSpacing`/`scrollDismissesKeyboard` 不可用 | iOS 16+ API，部署目标 15 | 部署目标提升至 16.0 |
| `captured var self in concurrently-executing code` | `Timer.scheduledTimer` @Sendable 闭包捕获 | 改用 Combine `Timer.publish` |
| `main actor-isolated` 校验方法报错 | `@MainActor` 类静态方法跨上下文调用 | 提取独立 `Validator` enum |
| pbxproj 解析失败（多一个 `{`） | 编辑 XCConfigurationList 时重复定义行 | 删除重复行，括号平衡校验 |

## 7. 后续迭代建议

- **接入真实接口**：以 `LoginViewModel` 中 `Task.sleep` 为占位点替换为网络请求；`Validator` 校验保留。
- **第三方登录**：未来按需增加 Apple/微信登录按钮，复用 `PrimaryButton` 变体。
- **深色模式**：移除 `preferredColorScheme(.light)`，按 README 第 8 章补充深色令牌。
- **真机验证**：模拟器无障碍；真机需测试键盘避让与短信验证码填充（`textContentType(.oneTimeCode)` 在真机生效）。
- **单元测试**：为 `Validator` 与 `LoginViewModel` 状态机补充 XCTest 单测。

---

*计划文档 · 2026-08-10 · 与 `index.html` 原型、`README.md` 设计规范配套使用*