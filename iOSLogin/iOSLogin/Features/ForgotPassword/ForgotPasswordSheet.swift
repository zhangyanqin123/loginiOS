import SwiftUI

// ============================================================
//  ForgotPasswordSheet · 忘记密码底部抽屉（阶段 5）
//  遮罩点击 / 关闭按钮 / Esc 均可关闭；提交后回调 toast
// ============================================================

struct ForgotPasswordSheet: View {
    @Binding var isPresented: Bool
    var toast: (ToastMessage) -> Void

    @State private var account = ""
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            if isPresented {
                // 遮罩
                Theme.dim
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .transition(.opacity)

                // 底部抽屉
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Theme.border2)
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)

                    HStack {
                        Text("忘记密码")
                            .font(Theme.fontTitle)
                            .foregroundColor(Theme.text1)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.text2)
                                .frame(width: 32, height: 32)
                                .background(Theme.surfaceMuted)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 18)

                    Text("输入注册时使用的手机号或邮箱，我们将发送重置指引。")
                        .font(Theme.fontCaption)
                        .foregroundColor(Theme.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(2)
                        .padding(.top, 6)

                    InputField(icon: "envelope.fill",
                               title: "",
                               placeholder: "手机号或邮箱",
                               text: $account,
                               keyboardType: .emailAddress,
                               maxLength: 100,
                               requiresClearButton: true)
                        .padding(.top, 20)

                    PrimaryButton(title: "发送重置指引",
                                  state: isSubmitting ? .loading : .enabled,
                                  height: 52) {
                        guard Validator.isValidEmailOrPhone(account) else {
                            toast(ToastMessage(text: "请输入正确的手机号或邮箱", type: .error))
                            return
                        }
                        isSubmitting = true
                        Task {
                            try? await Task.sleep(nanoseconds: 900_000_000)
                            isSubmitting = false
                            dismiss()
                            toast(ToastMessage(text: "重置指引已发送", type: .success))
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 34)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusModal, style: .continuous)
                        .fill(Theme.surface)
                        .shadow(color: Theme.shadowModal, radius: 64, y: 24)
                )
                .clipped()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: Theme.durSlow), value: isPresented)
        .ignoresSafeArea(.container)
    }

    private func dismiss() {
        isPresented = false
        account = ""
        isSubmitting = false
    }
}