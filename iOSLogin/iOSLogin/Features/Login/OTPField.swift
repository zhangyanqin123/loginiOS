import SwiftUI

// ============================================================
//  OTPField · 6 位验证码输入
//  单 TextField（透明文字 + 品牌色 caret）+ 6 个视觉格子
//  textContentType(.oneTimeCode) 可触发 iOS 短信自动填充
// ============================================================

struct OTPField: View {
    @Binding var otp: String
    var isError = false
    var shakeCount: CGFloat = 0
    var onComplete: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    private let digitCount = 6

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<digitCount, id: \.self) { index in
                    cell(character(at: index),
                         isCurrent: isFocused && index == otp.count)
                }
            }

            // 透明输入层：覆盖全部格子区域，任意位置点击即可聚焦
            TextField("", text: $otp, prompt: nil)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .tint(Theme.primary)
                .foregroundColor(.clear)
                .autocorrectionDisabled()
                .accessibilityLabel("6 位验证码")
                .accessibilityIdentifier("otpInput")
                .onChange(of: otp) { _ in sanitize() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Theme.otpCellHeight)
        .modifier(ShakeEffect(animatableData: shakeCount))
    }

    // MARK: - 格子
    private func cell(_ char: Character?, isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: Theme.radiusOTP, style: .continuous)
            .fill(Theme.surface)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.otpCellHeight)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusOTP, style: .continuous)
                    .stroke(isError ? Theme.error : (isCurrent ? Theme.primary : Theme.border),
                            lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusOTP + 4, style: .continuous)
                    .stroke(isError ? Theme.errorRing : Theme.focusRing, lineWidth: 4)
                    .padding(-4)
                    .opacity(isCurrent || isError ? 1 : 0)
            )
            .overlay(
                Text(char.map { String($0) } ?? "")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.text1)
            )
    }

    // MARK: - 清洗与分发
    private func sanitize() {
        let filtered = String(otp.filter(\.isNumber).prefix(digitCount))
        if filtered != otp {
            otp = filtered
        }
        if otp.count == digitCount {
            onComplete?()
        }
    }

    private func character(at index: Int) -> Character? {
        guard index < otp.count else { return nil }
        return otp[otp.index(otp.startIndex, offsetBy: index)]
    }
}