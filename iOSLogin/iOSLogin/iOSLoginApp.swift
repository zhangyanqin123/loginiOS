import SwiftUI

@main
struct iOSLoginApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light) // 原型为浅色设计，接入深色模式时移除该行
        }
    }
}

/// 根视图：承载登录页 / 注册页 / 弹窗 / Toast / 成功遮罩等全局层
struct RootView: View {
    var body: some View {
        LoginView()
    }
}