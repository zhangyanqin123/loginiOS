import SwiftUI

// ============================================================
//  SuccessOverlay · 登录成功全屏遮罩（阶段 5）
//  品牌渐变全屏 + 圆环对勾描边动画 + 文案 stagger 上浮
// ============================================================

struct SuccessOverlay: View {
    @Binding var isVisible: Bool
    @State private var drawProgress: CGFloat = 0    // 对勾描边 0→1
    @State private var textUp = false                // 文案上浮

    private let circleSize: CGFloat = 120

    var body: some View {
        ZStack {
            if isVisible {
                Theme.gradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: circleSize, height: circleSize)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.65), lineWidth: 3)
                            )

                        checkPath
                    }
                    .onAppear {
                        drawProgress = 0
                        textUp = false
                        withAnimation(.easeOut(duration: 0.7).delay(0.1)) { drawProgress = 1 }
                        withAnimation(.easeOut(duration: 0.5).delay(0.7)) { textUp = true }
                    }

                    Text("登录成功")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 28)
                        .opacity(textUp ? 1 : 0)
                        .offset(y: textUp ? 0 : 12)

                    Text("欢迎回来，开始探索吧")
                        .font(Theme.fontCaption)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.top, 10)
                        .opacity(textUp ? 1 : 0)
                        .offset(y: textUp ? 0 : 12)
                }
                .scaleEffect(isVisible ? 1 : 0.92)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: Theme.durSlow), value: isVisible)
        .ignoresSafeArea()
    }

    /// 对勾路径（描边动画）
    private var checkPath: some View {
        Path { path in
            path.move(to: CGPoint(x: 40, y: 62))
            path.addLine(to: CGPoint(x: 54, y: 76))
            path.addLine(to: CGPoint(x: 80, y: 48))
        }
        .trim(from: 0, to: drawProgress)
        .stroke(Color.white,
                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        .frame(width: circleSize, height: circleSize)
    }
}