import SwiftUI

// ============================================================
//  RegisterView · 注册页（stub，阶段 5）
//  手机号 / 密码 / 确认密码 + 协议勾选 + 注册按钮
//  本页为入口跳转示意：校验通过后回调 onRegister 并返回登录页
// ============================================================

struct RegisterView: View {
    var onBack: () -> Void
    var onRegister: (ToastMessage) -> Void

    @State private var phone = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var agreed = false
    @State private var phoneError: String?
    @State private var passwordError: String?
    @State private var confirmError: String?
    @State private var buttonState: ButtonState = .disabled
    @State private var isSubmitting = false
    @State private var shakePhone: CGFloat = 0
    @State private var shakePassword: CGFloat = 0
    @State private var shakeConfirm: CGFloat = 0
    @State private var toast: ToastMessage?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 40)

                    fields
                        .padding(.top, 28)

                    agreeRow
                        .padding(.top, 24)

                    PrimaryButton(title: "注 册", state: buttonState) {
                        submit()
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, Theme.pagePadding)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .topLeading) {
            backButton
                .padding(.top, 6)
                .padding(.leading, 20)
        }
        .toast($toast)
        .onChange(of: phone)    { _ in recompute() }
        .onChange(of: password) { _ in recompute() }
        .onChange(of: confirm)  { _ in recompute() }
        .onChange(of: agreed)   { _ in recompute() }
    }

    // MARK: - 返回按钮
    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.text1)
                .frame(width: 36, height: 36)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("返回登录")
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

            Text("创建账号")
                .font(Theme.fontHero)
                .foregroundColor(Theme.text1)
                .padding(.top, 18)

            Text("填写以下信息，即刻开始体验")
                .font(Theme.fontBody)
                .foregroundColor(Theme.text2)
                .padding(.top, 8)
        }
    }

    // MARK: - 表单
    private var fields: some View {
        VStack(spacing: Theme.fieldSpacing) {
            InputField(icon: "iphone",
                       title: "手机号",
                       placeholder: "请输入手机号",
                       text: $phone,
                       keyboardType: .numberPad,
                       textContentType: .telephoneNumber,
                       maxLength: 11,
                       errorMessage: phoneError,
                       requiresClearButton: true,
                       onBlur: {
                           phoneError = Validator.isValidPhone(phone) ? nil : "请输入正确的手机号"
                           if phoneError != nil { triggerShake(&shakePhone) }
                       })
                .modifier(ShakeEffect(animatableData: shakePhone))

            InputField(icon: "lock.fill",
                       title: "设置密码",
                       placeholder: "6-20 位，含字母和数字",
                       text: $password,
                       isSecure: true,
                       maxLength: 20,
                       errorMessage: passwordError,
                       onBlur: {
                           passwordError = Validator.isValidPassword(password) ? nil : "密码需为 6-20 位，且包含字母和数字"
                           if passwordError != nil { triggerShake(&shakePassword) }
                       })
                .modifier(ShakeEffect(animatableData: shakePassword))

            InputField(icon: "lock.fill",
                       title: "确认密码",
                       placeholder: "请再次输入密码",
                       text: $confirm,
                       isSecure: true,
                       maxLength: 20,
                       errorMessage: confirmError,
                       onBlur: {
                           confirmError = confirm == password ? nil : "两次输入的密码不一致"
                           if confirmError != nil { triggerShake(&shakeConfirm) }
                       })
                .modifier(ShakeEffect(animatableData: shakeConfirm))
        }
    }

    // MARK: - 协议行
    private var agreeRow: some View {
        HStack(alignment: .top, spacing: 10) {
            CustomCheckbox(isChecked: $agreed)
                .padding(.top, 1)

            HStack(spacing: 0) {
                Text("我已阅读并同意")
                    .font(Theme.fontMicro)
                    .foregroundColor(Theme.text2)
                Button("《用户协议》") {
                    toast = ToastMessage(text: "用户协议内容为演示占位", type: .info)
                }
                .font(Theme.fontMicro)
                .fontWeight(.semibold)
                .foregroundColor(Theme.primary)
                .buttonStyle(.plain)
                Text("与")
                    .font(Theme.fontMicro)
                    .foregroundColor(Theme.text2)
                Button("《隐私政策》") {
                    toast = ToastMessage(text: "隐私政策内容为演示占位", type: .info)
                }
                .font(Theme.fontMicro)
                .fontWeight(.semibold)
                .foregroundColor(Theme.primary)
                .buttonStyle(.plain)
            }
            .lineSpacing(2)
        }
    }

    // MARK: - 逻辑
    private func recompute() {
        if isSubmitting { return }
        let valid = Validator.isValidPhone(phone)
            && Validator.isValidPassword(password)
            && confirm == password
        buttonState = (valid && agreed) ? .enabled : .disabled
    }

    private func submit() {
        guard agreed else {
            toast = ToastMessage(text: "请先阅读并同意用户协议", type: .error)
            return
        }
        phoneError = Validator.isValidPhone(phone) ? nil : "请输入正确的手机号"
        passwordError = Validator.isValidPassword(password) ? nil : "密码需为 6-20 位，且包含字母和数字"
        confirmError = confirm == password ? nil : "两次输入的密码不一致"
        if phoneError != nil { triggerShake(&shakePhone) }
        if passwordError != nil { triggerShake(&shakePassword) }
        if confirmError != nil { triggerShake(&shakeConfirm) }
        guard phoneError == nil, passwordError == nil, confirmError == nil else { return }

        isSubmitting = true
        buttonState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)   // 模拟请求 1.2s
            isSubmitting = false
            onRegister(ToastMessage(text: "已模拟注册成功", type: .success))
        }
    }
}