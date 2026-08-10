# iOS 登录页 · 高保真交互原型 — 设计规范

> 本原型由产品经理 / 设计师产出，旨在为 iOS 开发团队提供**可直接对照实现**的登录页视觉与交互规范。
> 原型文件：`index.html`（自包含，无外部依赖，双击即可在浏览器打开）。

---

## 1. 原型说明与运行方式

| 项目 | 说明 |
|---|---|
| 文件 | `index.html`（内联 CSS/JS，单文件交付） |
| 运行 | 双击用 Chrome / Safari / Edge 打开即可；建议打开浏览器开发者工具，使用设备模拟选择 **iPhone 15 Pro（390×844）** 对照查看 |
| 基准机型 | iPhone 15 Pro，逻辑分辨率 390×844 pt |
| 视觉风格 | 品牌蓝紫渐变 `#5B7CFF → #8A5CFF` + 现代简约，浅色背景 |
| 文案语言 | 简体中文 |
| 演示辅助 | 页面右下角提供「重置演示」「键盘开关」按钮，用于演示讲解 |

**原型覆盖范围**：密码登录、验证码登录、注册页（stub）、忘记密码弹窗、登录成功动效、Toast、模拟键盘。

---

## 2. 设计令牌 → iOS 映射表

所有颜色在 `index.html` 的 `:root` 中以 CSS 变量定义，下方给出对应的 iOS 写法。建议在 Asset Catalog 中按语义命名（`brandPrimary` / `brandSecondary` / `brandGradient` 等），避免散落硬编码。

### 2.1 颜色

| 令牌 | 色值 | 用途 | iOS（UIColor / SwiftUI Color） |
|---|---|---|---|
| `--c-primary-500` | `#5B7CFF` | 品牌主色：聚焦边框、Tab 强调、链接 | `Color(red: 0.357, green: 0.486, blue: 1.0)` |
| `--c-primary-600` | `#4A6CF0` | 按钮按压态 | `Color(red: 0.29, green: 0.424, blue: 0.941)` |
| `--c-primary-700` | `#3D5CE0` | 深按压 / Tab 激活文字 | `Color(red: 0.239, green: 0.361, blue: 0.878)` |
| `--c-secondary-500` | `#8A5CFF` | 品牌辅色（渐变终点） | `Color(red: 0.541, green: 0.361, blue: 1.0)` |
| `--c-gradient` | `linear-gradient(135deg, #5B7CFF, #8A5CFF)` | 主按钮 / 勾选 / 成功遮罩 | SwiftUI：`LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)` |
| `--c-bg` | `#F7F8FC` | 页面背景 | `Color(hex: 0xF7F8FC)` |
| `--c-surface` | `#FFFFFF` | 输入框 / 卡片 | `.white` |
| `--c-surface-muted` | `#F3F4F8` | 禁用输入框底 / Tab 底槽 | `Color(hex: 0xF3F4F8)` |
| `--c-text-1` | `#1A1D2B` | 主文字 | `Color(hex: 0x1A1D2B)` |
| `--c-text-2` | `#5A6072` | 次要文字 | `Color(hex: 0x5A6072)` |
| `--c-text-3` | `#9AA1B2` | 占位符 | `Color(hex: 0x9AA1B2)` |
| `--c-border` | `#E6E8F0` | 默认边框 | `Color(hex: 0xE6E8F0)` |
| `--c-border-2` | `#D5D9E5` | 次级边框：勾选框 | `Color(hex: 0xD5D9E5)` |
| `--c-success` | `#34C759` | 成功态 | System 同款绿 `Color(red: 0.204, green: 0.78, blue: 0.349)` |
| `--c-error` | `#FF3B30` | 错误 | 系统红 `Color(red: 1.0, green: 0.231, blue: 0.188)` |
| `--c-error-bg` | `#FFF0EF` | 错误提示底色 | `Color(hex: 0xFFF0EF)` |
| `--c-toast-bg` | `rgba(26,29,43,.88)` | Toast 底 | `Color.black.opacity(0.88)` |
| `--c-dim` | `rgba(20,24,40,.5)` | 弹窗遮罩 | `Color.black.opacity(0.5)` |

> 建议封装 `Color(hex:)` 扩展，参考：[SwiftUI Color Hex 扩展](https://developer.apple.com/documentation/swiftui/color)。

### 2.2 字体

| 层级 | 字号/字重 | CSS | SwiftUI 对照 |
|---|---|---|---|
| 主标题 | 34 / Bold | `--fs-hero` | `.font(.system(size: 34, weight: .bold))` ≈ `largeTitle` |
| 弹窗标题 | 20 / Bold | — | `.title3.bold()` |
| 正文 | 17 / Regular | `--fs-body` | `.body` |
| 输入文字 | 15 / Medium | `--fs-input` | `.callout.weight(.medium)` |
| 辅助文字 | 13 / Regular | `--fs-caption` | `.caption` |
| 说明文字 | 12 / Regular | `--fs-micro` | `.caption2` |
| 主按钮 | 17 / Semibold | `--fs-btn` | `.body.weight(.semibold)` |

### 2.3 圆角 / 阴影 / 间距

**圆角**：输入框 14、卡片 20、主按钮 28（接近胶囊）、弹窗 24、OTP 格 12、勾选框 7、Tab 胶囊 999 → SwiftUI 用 `.cornerRadius` 或 `.clipShape(RoundedRectangle(cornerRadius:))`。

**阴影**：
| 层级 | 参数 | SwiftUI |
|---|---|---|
| 输入框 | `0 1px 2px rgba(16,24,40,.05)` | `.shadow(color: .black.opacity(0.05), radius: 2, y: 1)` |
| 主按钮 | `0 10px 24px rgba(91,124,255,.38)` | `.shadow(color: .brand.opacity(0.38), radius: 24, y: 10)` |
| 卡片 | `0 12px 32px rgba(16,24,40,.08)` | `.shadow(color: .black.opacity(0.08), radius: 32, y: 12)` |
| 弹窗 | `0 24px 64px rgba(16,24,40,.18)` | `.shadow(color: .black.opacity(0.18), radius: 64, y: 24)` |
| Toast | `0 8px 24px rgba(16,24,40,.16)` | `.shadow(color: .black.opacity(0.16), radius: 24, y: 8)` |

**间距刻度**：4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48。页面左右留白统一 **24**；字段间距 18；主按钮上方 24。

---

## 3. 布局与栅格

### 3.1 页面结构（自上而下）

```
┌──────────────────────────────┐
│ 状态栏 54pt（时间 / 灵动岛 / 电量）│
├──────────────────────────────┤
│ Logo 64×64 + 主标题 34 + 副标题   │   ← 页面上留白 84pt
│ Tab 胶囊（44pt 高，含滑动指示器）  │
│ 输入字段 × N（14pt 圆角白底卡片）  │
│ 协议勾选（22×22 渐变勾选框）      │
│ 主按钮 56pt（渐变胶囊）           │
│ 忘记密码 / 注册入口              │
└──────────────────────────────┘
```

### 3.2 安全区

| 区域 | 值 | 说明 |
|---|---|---|
| 顶部安全区 | 54pt | 含灵动岛区域（灵动岛 126×37，居中） |
| 底部安全区 | 34pt | Home Indicator |
| 页面左右留白 | 24pt | 统一间距基准 |

SwiftUI：内容容器使用 `safeAreaPadding()` 或 `.padding(.horizontal, 24)`，整页 `ignoresSafeArea` 后手动处理顶部 54pt。

### 3.3 登录方式双 Tab

- 两个 Tab 等宽（各 50%），胶囊底槽 + 白色滑动指示器（`ease-spring` 曲线）。
- SwiftUI 实现：`@Namespace` + `matchedGeometryEffect` 实现指示器滑动；或自定义 `UISegmentedControl`。

---

## 4. 组件规格与状态

### 4.1 文本输入框 `InputField`

| 状态 | 边框 | 背景 | 其他 |
|---|---|---|---|
| Default | `--c-border` | 白 | 占位符 `--c-text-3` |
| Focus | `--c-primary-500` + 4px 光环 `rgba(91,124,255,.16)` | 白 | caret 品牌色 |
| Filled | 同 Default | 白 | 右侧显示清空 × 按钮 |
| Error | `--c-error` + 4px 红光环 | 白 | 下方错误文案 + 触发 shake |
| Disabled | `--c-border` | `--c-surface-muted` | 文字 `--c-text-3` |

- 前缀图标（邮箱/锁/手机）聚焦时由灰变品牌色。
- 密码框右侧眼睛按钮：`password ↔ text` 切换，切换后保持焦点。

**SwiftUI 提示**：自定义 `InputFieldView`（`@FocusState`），通过 `@Binding` 暴露状态枚举 `default/focused/filled/error`；UIViewRepresentable 包 `UITextField` 时用 layer 画边框与光环。

### 4.2 验证码发送按钮 `SendCodeButton`

| 状态 | 样式 |
|---|---|
| Idle | 透明底 + 品牌色描边 + 品牌色文字「获取验证码」 |
| Counting | 灰底灰字「N 秒后重新获取」，`disabled` |
| 校验失败 | 不进入倒计时，手机号输入框 shake + 错误文案 |

倒计时 **60s**，归零后恢复「重新获取」。

### 4.3 OTP 验证码（6 位）

**推荐实现**：单个 `TextField`（`textContentType = .oneTimeCode`，可触发 iOS 短信自动填充）+ 下层 6 个视觉格（`Text` 展示字符）。输入层文字透明、caret 品牌色，实时按长度回填格子并高亮当前位。

| 状态 | 样式 |
|---|---|
| Empty | 6 个白底格，边框 `--c-border` |
| Focused | 当前输入位品牌边框 + 光环 |
| Filled | 格子显示数字 |
| Complete（6 位） | 触发表单整体重算 |
| Error | 全部格子红框 + shake |

**自动跳格备选方案**（若选用 6 个独立输入框）：`input` 取末位、空位获取焦点；退格时空格回跳上一格；`paste` 分发 6 位并聚焦末格；`@FocusState` 数组逐一管理。

### 4.4 主按钮 `LoginButton`（状态机）

| 状态 | 样式 |
|---|---|
| Disabled | 渐变 40% 透明度、无阴影、不可点击 |
| Default | 渐变底 + 品牌投影，按压 `scale(0.98)` |
| Loading | 文字「登录中…」+ 白色旋转 spinner，防重复点击 |
| Success | 底色切 `--c-success` 绿 + 白色对勾，400ms 后进入全屏遮罩 |

**SwiftUI 提示**：`ButtonStyle` 内维护状态机，或 `UIButton` 四态图片/属性；`disabled` 时调整 `opacity` 与 `shadow`。

### 4.5 协议勾选

- 22×22 圆角勾选框：未选白底描边，选中渐变底 + 白色对勾（150ms 回弹）。
- 未勾选时主按钮禁用；点击《用户协议》《隐私政策》链接弹 Toast（占位）。
- 勾选框与文字整体可点击（`Label` 包在 `Button` / `Toggle` 中）。

### 4.6 Toast / 弹窗 / 成功遮罩

| 组件 | 规格 |
|---|---|
| Toast | 顶部滑入胶囊，深色底 88% 透明度，三种变体（info/success/error），2.2s 自动消失，单例复用 |
| 忘记密码弹窗 | 底部抽屉（24pt 顶部圆角）+ 半透明遮罩；遮罩点击 / 关闭按钮 / Esc 关闭 |
| 成功遮罩 | 全屏品牌渐变 + 圆环对勾 SVG 描边动画 + 文案 stagger 上浮，2.5s 后收起并重置表单 |

---

## 5. 交互行为实现要点

| 行为 | 规则 | iOS 实现要点 |
|---|---|---|
| 实时校验 | 输入时清洗（手机号仅数字限 11 位、密码限 20 位），blur 时校验，错误在输入恢复时立即清除 | `onChange(of: value)` 做清洗；`onSubmit`/失焦校验 |
| 手机号 | `/^1[3-9]\d{9}$/` | `NSPredicate(format: "SELF MATCHES %@", "^1[3-9]\\\\d{9}$")` |
| 邮箱 | `/^[^\s@]+@[^\s@]+\.[^\s@]+$/` | 同上，或 `NSPredicate` 邮箱正则 |
| 密码 | 6-20 位，同时含字母与数字 | 自定义校验函数 |
| 错误反馈 | 红框 + 抖动动画 + 文案（`aria-live` 等效 VoiceOver） | `withAnimation` 抖动；**建议叠加 `UINotificationFeedbackGenerator().notificationOccurred(.error)` 触感** |
| 倒计时 | 60s，`setInterval` 秒级递减，`pagehide` 清理 | SwiftUI `Timer.publish(every: 1, on: .main)` + `.onDisappear` 取消；TestFlight 弱网时允许重发（通常 60s 内禁用） |
| Tab 切换 | 指示器 spring 滑动 + 面板 fade-in-up；切换不清空 OTP/倒计时 | `matchedGeometryEffect`；面板切 Retained 状态 |
| 登录提交 | 二次全量校验 → loading 1.4s → success → 全屏遮罩 → 重置表单 | `isSubmitting` 防连点；建议接真实接口后用 `async/await` 替换延时 |
| 页面过渡 | 登录页左移淡出，注册页从右滑入（420ms） | `NavigationStack` push 动画或自定义 `transition(.move(edge: .trailing))` |
| 键盘处理 | 输入聚焦时内容上移避开键盘；真实 App 无需模拟键盘 | SwiftUI 自动处理；`@FocusState` 管理收起 |

---

## 6. 动效参数表

| 动效 | 时长 | 缓动 | CSS 曲线 | SwiftUI 对照 |
|---|---|---|---|---|
| 常态出场 | 250ms | `--ease-out` | `cubic-bezier(.22,1,.36,1)` | `.easeOut(duration: 0.25)` |
| 面板/页面切换 | 420ms | `--ease-out` | `cubic-bezier(.22,1,.36,1)` | `.easeOut(duration: 0.42)` |
| 快速反馈 | 150ms | `--ease-out` | `cubic-bezier(.22,1,.36,1)` | `.easeOut(duration: 0.15)` |
| Tab 指示器 | 250ms | spring | `cubic-bezier(.34,1.3,.64,1)` | `.spring(response: 0.3, dampingFraction: 0.8)` |
| 错误抖动 | 500ms | 正弦回弹 | 自定义 keyframes | `withAnimation(.interpolatingSpring)` 或 `UIView.animate` 平移序列 |
| 对勾描边 | 600ms | ease-out + 延迟 | SVG `stroke-dashoffset` | `trim(from: 0, to: 1)` + `withAnimation(.easeOut(duration: 0.6).delay(0.1))` |
| 成功遮罩 | 如表格 | — | opacity + scale | `.transition(.scale)` 组合 |

**无障碍**：遵循 `prefers-reduced-motion`，系统开启「减弱动态效果」时关闭抖动/对勾/弹簧动画（SwiftUI 用 `@Environment(\.accessibilityReduceMotion)`）。

---

## 7. 文案资源清单

> 全部文案集中在 `index.html` 的 `TEXT` 配置对象中，可直接导出为本地化字符串文件。

| Key | 中文 | 备注 |
|---|---|---|
| titleLogin | 欢迎回来 | 登录页主标题 |
| subtitleLogin | 登录后享受更完整的功能体验 | 登录页副标题 |
| tabPassword / tabSms | 密码登录 / 验证码登录 | Tab |
| btnLogin / btnRegister | 登 录 / 注 册 | 主按钮 |
| loginLoading | 登录中… | Loading 态 |
| loginSuccess / loginSuccessSub | 登录成功 / 欢迎回来，开始探索吧 | 成功遮罩 |
| sendCode / sendCodeAgain | 获取验证码 / 重新获取 | 发送按钮 |
| countdown | `{n} 秒后重新获取` | 倒计时 |
| error.email | 请输入正确的邮箱或账号 | |
| error.password | 密码需为 6-20 位，且包含字母和数字 | |
| error.phone | 请输入正确的手机号 | |
| error.sms | 请输入 6 位验证码 | |
| error.confirm | 两次输入的密码不一致 | 注册页 |
| toast.codeSent | 验证码已发送 | |
| toast.needAgree | 请先阅读并同意用户协议 | |
| toast.protocol | `{name}内容为演示占位` | 协议链接 |
| toast.resetSent | 重置指引已发送 | 忘记密码 |
| toast.registerOK | 已模拟注册成功 | |
| toast.demoDone | 演示已完成 | 登录成功收起 |
| 弹窗标题 / 描述 | 忘记密码 / 输入注册时使用的手机号或邮箱，我们将发送重置指引。 | |
| 注册页 | 创建账号 / 填写以下信息，即刻开始体验 | |
| 占位符 | 请输入邮箱或账号 / 6-20 位，含字母和数字 / 请输入手机号 / 请再次输入密码 | |
| 协议 | 我已阅读并同意《用户协议》《隐私政策》 | 链接可点击 |

---

## 8. 边界情况与验收清单

### 8.1 边界情况

- **连点**：登录/注册/发送按钮均需防重复提交（loading 期间禁用）。
- **倒计时跨页面**：Tab 切换、页面切换不重置倒计时；退出页面时清理 Timer。
- **校验时序**：blur 时校验；输入恢复立即清除错误（不等 blur）。
- **弱网**：loading 态需可中断/超时；原型用 1.4s 延时模拟，真实实现替换为接口请求。
- **无障碍**：真机可用 VoiceOver 走通全流程（`aria-label` 对应 `accessibilityLabel`）。
- **深色模式**：本原型为浅色设计，接入时建议补充深色色值（背景 `#0E1017`、表面 `#1A1D2B`、边框 `#2A2E3D`、文字反色），用 `@Environment(\.colorScheme)` 切换。

### 8.2 验收清单（QA 回归）

- [ ] 密码登录：非法邮箱/密码 → 错误态 + 抖动；合法 + 勾选协议 → 按钮可用
- [ ] 验证码登录：非法手机号点发送 → 被拒；合法 → 60s 倒计时、按钮禁用、归零恢复
- [ ] OTP：粘贴 6 位自动填满；非数字输入被过滤；退格逐格回退
- [ ] 登录全流程：loading → 成功 → 全屏遮罩 → 表单重置；过程中不可重复点击
- [ ] 注册页：滑入/返回过渡；确认密码不一致 → 错误提示；注册成功 → 返回登录
- [ ] 忘记密码：弹窗开合（遮罩/关闭按钮/Esc）；提交后 Toast 提示
- [ ] 全局：无控制台报错；`prefers-reduced-motion` 下动画关闭；窗口缩放适配

### 8.3 非本迭代范围（开发时请勿误判为准入）

- 注册页为 **stub**，仅做入口跳转示意，未接入真实注册逻辑
- 协议 / 隐私政策内容为**占位**，链接仅弹 Toast
- **未包含第三方登录**（Apple / 微信 / Google）——已按决策剔除
- 模拟键盘为纯视觉演示，真实 App 使用系统键盘

---

*原型文件：`index.html` · 设计规范：本文件 · 产出日期：2026-08-10*