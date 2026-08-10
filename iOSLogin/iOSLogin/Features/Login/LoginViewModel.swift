import SwiftUI
import Combine

// ============================================================
//  LoginViewModel · 登录表单状态机
//  字段状态 / 校验规则 / 倒计时 / 发送验证码 / 登录流程
// ============================================================

enum LoginMode: String, CaseIterable {
    case password     // 密码登录
    case sms          // 验证码登录

    var title: String {
        switch self {
        case .password: return "密码登录"
        case .sms:      return "验证码登录"
        }
    }
}

// MARK: - 校验规则（与 index.html 的 validators 一致）
/// 独立于 ViewModel，供登录 / 注册 / 忘记密码等各处复用
enum Validator {
    static func isValidEmail(_ s: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return s.trimmingCharacters(in: .whitespaces).range(of: pattern, options: .regularExpression) != nil
    }
    static func isValidPassword(_ s: String) -> Bool {
        let pattern = #"^(?=.*[A-Za-z])(?=.*\d)[\w@#$%^&*+=!.-]{6,20}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }
    static func isValidPhone(_ s: String) -> Bool {
        let pattern = #"^1[3-9]\d{9}$"#
        return s.trimmingCharacters(in: .whitespaces).range(of: pattern, options: .regularExpression) != nil
    }
    static func isValidOTP(_ s: String) -> Bool {
        s.count == 6 && s.allSatisfy(\.isNumber)
    }
    static func isValidEmailOrPhone(_ s: String) -> Bool {
        isValidEmail(s) || isValidPhone(s)
    }
}

@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: - 登录方式
    @Published var loginMode: LoginMode = .password

    // MARK: - 密码登录字段
    @Published var email = ""
    @Published var password = ""
    @Published var emailError: String?
    @Published var passwordError: String?

    // MARK: - 验证码登录字段
    @Published var phone = ""
    @Published var phoneError: String?
    @Published var otp = ""
    @Published var otpError: String?

    // MARK: - 协议与按钮
    @Published var agreed = false
    @Published var buttonState: ButtonState = .disabled
    @Published var isSubmitting = false

    // MARK: - 验证码倒计时
    @Published var countdown = 0             // 剩余秒数
    @Published var codeSent = false          // 是否已发送过
    private var countdownCancellable: AnyCancellable?

    // MARK: - 全局层
    @Published var showForgotPassword = false
    @Published var showRegister = false
    @Published var showSuccess = false       // 登录成功遮罩
    @Published var toast: ToastMessage?

    // MARK: - 实时清洗
    func cleanIfNeeded(_ value: String) {
        // 清洗逻辑由 InputField 的 onChange + 表单绑定完成，此处仅做最大长度约束兜底
        if email.count > 100 { email = String(email.prefix(100)) }
        if password.count > 20 { password = String(password.prefix(20)) }
        if phone.count > 11 { phone = String(phone.prefix(11)) }
        if otp.count > 6 { otp = String(otp.prefix(6)) }
    }

    /// 输入变化时清除对应字段错误
    func clearError(_ field: LoginField) {
        switch field {
        case .email:     emailError = nil
        case .password:  passwordError = nil
        case .phone:     phoneError = nil
        case .otp:       otpError = nil
        }
    }

    // MARK: - 按钮启停（集中式 recompute）
    func recomputeButton() {
        if isSubmitting { return }
        let fieldsValid: Bool
        switch loginMode {
        case .password:
            fieldsValid = Validator.isValidEmail(email) && Validator.isValidPassword(password)
        case .sms:
            fieldsValid = Validator.isValidPhone(phone) && Validator.isValidOTP(otp)
        }
        buttonState = (fieldsValid && agreed) ? .enabled : .disabled
    }

    // MARK: - 失焦校验
    func validateOnBlur(_ field: LoginField) {
        switch field {
        case .email:
            emailError = Validator.isValidEmail(email) ? nil : "请输入正确的邮箱或账号"
        case .password:
            passwordError = Validator.isValidPassword(password) ? nil : "密码需为 6-20 位，且包含字母和数字"
        case .phone:
            phoneError = Validator.isValidPhone(phone) ? nil : "请输入正确的手机号"
        case .otp:
            otpError = Validator.isValidOTP(otp) ? nil : "请输入 6 位验证码"
        }
        recomputeButton()
    }

    // MARK: - 发送验证码（前置校验 + 60s 倒计时）
    func sendCode() {
        guard Validator.isValidPhone(phone) else {
            phoneError = "请输入正确的手机号"
            recomputeButton()
            return
        }
        phoneError = nil
        guard countdown == 0 else { return }
        codeSent = true
        countdown = 60
        countdownCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.countdown -= 1
                if self.countdown <= 0 {
                    self.countdownCancellable?.cancel()
                    self.countdownCancellable = nil
                }
            }
        toast = ToastMessage(text: "验证码已发送", type: .success)
    }

    var sendCodeTitle: String {
        if countdown > 0 { return "\(countdown) 秒后重新获取" }
        return codeSent ? "重新获取" : "获取验证码"
    }

    // MARK: - 登录流程
    func login() {
        guard !isSubmitting else { return }
        guard agreed else {
            toast = ToastMessage(text: "请先阅读并同意用户协议", type: .error)
            return
        }
        // 提交前二次全量校验
        switch loginMode {
        case .password:
            if !Validator.isValidEmail(email) { emailError = "请输入正确的邮箱或账号" }
            if !Validator.isValidPassword(password) { passwordError = "密码需为 6-20 位，且包含字母和数字" }
        case .sms:
            if !Validator.isValidPhone(phone) { phoneError = "请输入正确的手机号" }
            if !Validator.isValidOTP(otp) { otpError = "请输入 6 位验证码" }
        }
        guard buttonState == .enabled else { recomputeButton(); return }

        isSubmitting = true
        buttonState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)      // 模拟请求 1.4s
            buttonState = .success
            try? await Task.sleep(nanoseconds: 400_000_000)        // 成功态停留 400ms
            showSuccess = true
            try? await Task.sleep(nanoseconds: 2_500_000_000)      // 成功遮罩 2.5s
            showSuccess = false
            resetForm()
            isSubmitting = false
            toast = ToastMessage(text: "演示已完成", type: .info)
        }
    }

    // MARK: - 重置
    func resetForm() {
        countdownCancellable?.cancel()
        countdownCancellable = nil
        countdown = 0
        email = ""; password = ""; phone = ""; otp = ""
        emailError = nil; passwordError = nil; phoneError = nil; otpError = nil
        agreed = false
        codeSent = false
        buttonState = .disabled
    }

    deinit {
        countdownCancellable?.cancel()
    }
}

enum LoginField {
    case email, password, phone, otp
}