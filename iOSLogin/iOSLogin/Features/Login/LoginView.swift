import SwiftUI

// ============================================================
//  LoginView · 登录主视图（阶段 2-3）
//  头部 + 双 Tab + 密码/验证码表单 + 协议 + 主按钮 + 入口
//  并承载注册页过渡 / 忘记密码弹窗 / 成功遮罩等全局层
// ============================================================

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @State private var shakeEmail: CGFloat = 0
    @State private var shakePassword: CGFloat = 0
    @State private var shakePhone: CGFloat = 0
    @State private var shakeOTP: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // ---- 页面区（登录 + 注册滑入过渡） ----
            ZStack {
                loginPage
                    .offset(x: vm.showRegister ? -88 : 0)
                    .opacity(vm.showRegister ? 0.4 : 1)

                if vm.showRegister {
                    RegisterView(
                        onBack: {
                            withAnimation(.easeOut(duration: Theme.durSlow)) { vm.showRegister = false }
                        },
                        onRegister: { toast in
                            vm.toast = toast
                            withAnimation(.easeOut(duration: Theme.durSlow)) { vm.showRegister = false }
                        }
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing),
                                            removal: .move(edge: .trailing)))
                }
            }
            .animation(.easeOut(duration: Theme.durSlow), value: vm.showRegister)

            // ---- 忘记密码弹窗 ----
            ForgotPasswordSheet(
                isPresented: $vm.showForgotPassword,
                toast: { msg in vm.toast = msg }
            )

            // ---- 登录成功遮罩 ----
            SuccessOverlay(isVisible: $vm.showSuccess)
        }
        .toast($vm.toast)
        .onChange(of: vm.email)    { _ in vm.recomputeButton() }
        .onChange(of: vm.password) { _ in vm.recomputeButton() }
        .onChange(of: vm.phone)    { _ in vm.recomputeButton() }
        .onChange(of: vm.otp)      { _ in vm.recomputeButton() }
        .onChange(of: vm.agreed)   { _ in vm.recomputeButton() }
    }

    // MARK: - Tab 选择 Binding
    private var modeIndex: Binding<Int> {
        Binding(get: { vm.loginMode == .password ? 0 : 1 },
                set: { newValue in
                    vm.loginMode = newValue == 0 ? .password : .sms
                    vm.recomputeButton()
                })
    }

    // MARK: - 登录页内容（可滚动）
    private var loginPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.top, 24)

                TabSlider(titles: LoginMode.allCases.map(\.title),
                          selection: modeIndex)
                    .padding(.top, 28)

                panel
                    .padding(.top, 24)

                agreeRow
                    .padding(.top, 24)

                loginButton
                    .padding(.top, 24)

                forgotLink
                    .padding(.top, 14)

                registerFooter
                    .padding(.top, 28)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, Theme.pagePadding)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - 头部
    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.gradient)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 64, height: 64)
            .shadow(color: Theme.primary.opacity(0.35), radius: 28, y: 12)

            Text("欢迎回来")
                .font(Theme.fontHero)
                .foregroundColor(Theme.text1)
                .padding(.top, 18)

            Text("登录后享受更完整的功能体验")
                .font(Theme.fontBody)
                .foregroundColor(Theme.text2)
                .padding(.top, 8)
        }
    }

    // MARK: - 表单面板（双 Tab 切换）
    @ViewBuilder private var panel: some View {
        ZStack {
            if vm.loginMode == .password {
                passwordFields.transition(.opacity)
            } else {
                smsFields.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Theme.durBase), value: vm.loginMode)
    }

    // MARK: - 密码登录表单
    private var passwordFields: some View {
        VStack(spacing: Theme.fieldSpacing) {
            InputField(icon: "envelope.fill",
                       title: "邮箱 / 账号",
                       placeholder: "请输入邮箱或账号",
                       text: $vm.email,
                       keyboardType: .emailAddress,
                       textContentType: .emailAddress,
                       maxLength: 100,
                       errorMessage: vm.emailError,
                       requiresClearButton: true,
                       onBlur: {
                           vm.validateOnBlur(.email)
                           if vm.emailError != nil { triggerShake(&shakeEmail) }
                       })
                .modifier(ShakeEffect(animatableData: shakeEmail))

            InputField(icon: "lock.fill",
                       title: "密码",
                       placeholder: "6-20 位，含字母和数字",
                       text: $vm.password,
                       isSecure: true,
                       maxLength: 20,
                       errorMessage: vm.passwordError,
                       onBlur: {
                           vm.validateOnBlur(.password)
                           if vm.passwordError != nil { triggerShake(&shakePassword) }
                       })
                .modifier(ShakeEffect(animatableData: shakePassword))
        }
    }

    // MARK: - 验证码登录表单
    private var smsFields: some View {
        VStack(spacing: Theme.fieldSpacing) {
            InputField(icon: "iphone",
                       title: "手机号",
                       placeholder: "请输入手机号",
                       text: $vm.phone,
                       keyboardType: .numberPad,
                       textContentType: .telephoneNumber,
                       maxLength: 11,
                       errorMessage: vm.phoneError,
                       requiresClearButton: true,
                       onBlur: {
                           vm.validateOnBlur(.phone)
                           if vm.phoneError != nil { triggerShake(&shakePhone) }
                       })
                .modifier(ShakeEffect(animatableData: shakePhone))

            VStack(alignment: .leading, spacing: 8) {
                Text("验证码")
                    .font(Theme.fontCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(vm.otpError != nil ? Theme.error : Theme.text2)
                    .padding(.leading, 2)

                HStack(spacing: 10) {
                    OTPField(otp: $vm.otp,
                             isError: vm.otpError != nil,
                             shakeCount: shakeOTP)
                    sendCodeButton
                }

                if let err = vm.otpError {
                    FieldError(text: err)
                }
            }
        }
    }

    // MARK: - 发送验证码按钮
    private var sendCodeButton: some View {
        Button {
            if Validator.isValidPhone(vm.phone) {
                vm.sendCode()
            } else {
                vm.validateOnBlur(.phone)
                triggerShake(&shakePhone)
            }
        } label: {
            Text(vm.sendCodeTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(vm.countdown > 0 ? Theme.text3 : Theme.primary)
                .frame(width: 108, height: Theme.otpCellHeight)
                .background(vm.countdown > 0 ? Color.clear : Theme.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusOTP))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusOTP)
                        .stroke(vm.countdown > 0 ? Theme.border : Theme.primary.opacity(0.28),
                                lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(vm.countdown > 0)
        .animation(.easeOut(duration: Theme.durFast), value: vm.countdown > 0)
    }

    // MARK: - 协议行
    private var agreeRow: some View {
        HStack(alignment: .top, spacing: 10) {
            CustomCheckbox(isChecked: $vm.agreed)
                .padding(.top, 1)

            HStack(spacing: 0) {
                Text("我已阅读并同意")
                    .font(Theme.fontMicro)
                    .foregroundColor(Theme.text2)
                Button("《用户协议》") {
                    vm.toast = ToastMessage(text: "用户协议内容为演示占位", type: .info)
                }
                .font(Theme.fontMicro)
                .fontWeight(.semibold)
                .foregroundColor(Theme.primary)
                .buttonStyle(.plain)
                Text("与")
                    .font(Theme.fontMicro)
                    .foregroundColor(Theme.text2)
                Button("《隐私政策》") {
                    vm.toast = ToastMessage(text: "隐私政策内容为演示占位", type: .info)
                }
                .font(Theme.fontMicro)
                .fontWeight(.semibold)
                .foregroundColor(Theme.primary)
                .buttonStyle(.plain)
            }
            .lineSpacing(2)
        }
    }

    // MARK: - 主按钮
    private var loginButton: some View {
        PrimaryButton(title: "登 录", state: vm.buttonState) {
            vm.login()
            if vm.emailError != nil    { triggerShake(&shakeEmail) }
            if vm.passwordError != nil { triggerShake(&shakePassword) }
            if vm.phoneError != nil    { triggerShake(&shakePhone) }
            if vm.otpError != nil      { triggerShake(&shakeOTP) }
        }
    }

    // MARK: - 忘记密码 / 注册入口
    private var forgotLink: some View {
        Button {
            vm.showForgotPassword = true
        } label: {
            Text("忘记密码？")
                .font(Theme.fontCaption)
                .foregroundColor(Theme.text2)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }

    private var registerFooter: some View {
        HStack(spacing: 4) {
            Text("还没有账号？")
                .font(Theme.fontMicro)
                .foregroundColor(Theme.text3)
            Button("立即注册") {
                withAnimation(.easeOut(duration: Theme.durSlow)) { vm.showRegister = true }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.primary)
            .buttonStyle(.plain)
        }
    }
}