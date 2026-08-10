import SwiftUI

// ============================================================
//  Components · 复用组件层
//  InputField / PrimaryButton / CustomCheckbox / TabSlider / Toast / Shake
// ============================================================

// MARK: - 按压反馈
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: Theme.durFast), value: configuration.isPressed)
    }
}

// MARK: - 输入框
/// 通用输入框：标题 + 前缀图标 + 聚焦/错误态 + 清空按钮 + 密码可见切换
struct InputField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var maxLength: Int?
    var errorMessage: String?
    var requiresClearButton = false
    var onBlur: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var showPassword = false

    private var borderColor: Color {
        if errorMessage != nil { return Theme.error }
        return isFocused ? Theme.primary : Theme.border
    }
    private var showRing: Bool { isFocused || errorMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.fontCaption)
                .fontWeight(.semibold)
                .foregroundColor(errorMessage != nil ? Theme.error : Theme.text2)
                .padding(.leading, 2)

            HStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .light))
                    .foregroundColor(isFocused ? Theme.primary : Theme.text3)
                    .frame(width: 44)
                    .frame(maxHeight: .infinity)

                fieldContent
                    .font(Theme.fontInput)
                    .foregroundColor(Theme.text1)
                    .focused($isFocused)

                if requiresClearButton { clearButton }
                if isSecure { secureToggle }
            }
            .frame(height: Theme.fieldHeight)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusInput + 4, style: .continuous)
                    .stroke(borderColor.opacity(0.16), lineWidth: 4)
                    .padding(-4)
                    .opacity(showRing ? 1 : 0)
                    .animation(.easeOut(duration: Theme.durFast), value: showRing)
            )

            if let errorMessage {
                FieldError(text: errorMessage)
            }
        }
        .onChange(of: text) { _ in applyMaxLength() }
        .onChange(of: isFocused) { focused in
            if !focused { onBlur?() }
        }
    }

    @ViewBuilder private var fieldContent: some View {
        if isSecure && !showPassword {
            SecureField(placeholder, text: $text)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } else {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var clearButton: some View {
        Button {
            text = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.text3)
        }
        .buttonStyle(.plain)
        .frame(width: 34, height: 34)
        .padding(.trailing, 8)
        .opacity(text.isEmpty ? 0 : 1)
        .allowsHitTesting(!text.isEmpty)
        .animation(.easeOut(duration: Theme.durFast), value: text.isEmpty)
    }

    private var secureToggle: some View {
        Button {
            showPassword.toggle()
        } label: {
            Image(systemName: showPassword ? "eye.slash" : "eye")
                .font(.system(size: 18))
                .foregroundColor(Theme.text3)
        }
        .buttonStyle(.plain)
        .frame(width: 34, height: 34)
        .padding(.trailing, 8)
    }

    private func applyMaxLength() {
        guard let maxLength else { return }
        if text.count > maxLength { text = String(text.prefix(maxLength)) }
    }
}

// MARK: - 错误文案
struct FieldError: View {
    let text: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13))
            Text(text)
                .font(Theme.fontMicro)
        }
        .foregroundColor(Theme.error)
        .padding(.leading, 2)
    }
}

// MARK: - 主按钮状态机
enum ButtonState: Equatable {
    case enabled, disabled, loading, success
}

/// 渐变主按钮：enabled / disabled / loading / success 四态
struct PrimaryButton: View {
    let title: String
    var state: ButtonState = .enabled
    var height: CGFloat = Theme.buttonHeight
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if state == .loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .frame(width: 18, height: 18)
                }
                if state == .success {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                }
                Text(title)
                    .font(Theme.fontButton)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(background)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: shadowColor, radius: 24, x: 0, y: 10)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(state != .enabled)
        .opacity(state == .disabled ? 0.4 : 1)
    }

    private var background: AnyShapeStyle {
        switch state {
        case .success: return AnyShapeStyle(Theme.success)
        default:       return AnyShapeStyle(Theme.gradient)
        }
    }
    private var shadowColor: Color {
        switch state {
        case .success:  return Theme.success.opacity(0.35)
        case .disabled: return .clear
        default:        return Theme.shadowButton
        }
    }
}

// MARK: - 协议勾选框
struct CustomCheckbox: View {
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isChecked.toggle()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusCheckbox, style: .continuous)
                    .fill(isChecked ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusCheckbox, style: .continuous)
                            .stroke(isChecked ? Color.clear : Theme.border2, lineWidth: 1.5)
                    )
                    .shadow(color: isChecked ? Theme.primary.opacity(0.35) : .clear, radius: 12, y: 4)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isChecked ? 1 : 0.4)
                    .opacity(isChecked ? 1 : 0)
            }
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("agreementCheckbox")
        .accessibilityLabel("同意用户协议与隐私政策")
    }
}

// MARK: - Tab 胶囊切换（滑动指示器）
struct TabSlider: View {
    let titles: [String]
    @Binding var selection: Int

    var body: some View {
        GeometryReader { geo in
            let width = (geo.size.width - 8) / CGFloat(titles.count)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceMuted)

                Capsule()
                    .fill(Color.white)
                    .frame(width: width, height: 44)
                    .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
                    .offset(x: 4 + CGFloat(selection) * width)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selection)

                HStack(spacing: 0) {
                    ForEach(0..<titles.count, id: \.self) { i in
                        Button {
                            selection = i
                        } label: {
                            Text(titles[i])
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(selection == i ? Theme.primary700 : Theme.text2)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: geo.size.width, height: 52)
        }
        .frame(height: Theme.tabHeight)
    }
}

// MARK: - Toast
enum ToastType { case info, success, error }

struct ToastMessage: Equatable {
    var text: String
    var type: ToastType = .info
}

struct ToastViewModifier: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let t = toast {
                ToastBubble(message: t)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.easeOut(duration: Theme.durBase)) { toast = nil }
                        }
                    }
            }
        }
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        modifier(ToastViewModifier(toast: toast))
    }
}

struct ToastBubble: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
            Text(message.text)
                .font(Theme.fontCaption)
            Spacer(minLength: 0)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(Theme.toastBg)
                .shadow(color: Theme.shadowToast, radius: 24, y: 8)
        )
    }

    private var iconName: String {
        switch message.type {
        case .info:    return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        }
    }
}

// MARK: - 错误抖动（配合视图内 @State shakeCount 使用）
struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 8
    var numOfShakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = animatableData
        let translation: CGFloat = travelDistance * sin(t * .pi * numOfShakes)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - 辅助工具
func triggerShake(_ count: inout CGFloat) {
    count = 0
    withAnimation(.easeInOut(duration: 0.5)) { count = 1 }
}