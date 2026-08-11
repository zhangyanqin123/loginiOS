import SwiftUI
import UIKit

/// 兼容 RN 原生模块访问 `delegate.window` 的需要。
/// SwiftUI 生命周期 App 的隐式 AppDelegate 没有 `window` 属性，
/// 会导致 RCTAppearance 等模块初始化时 `unrecognized selector` 崩溃。
final class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
}

@main
struct iOSLoginApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light) // 原型为浅色设计，接入深色模式时移除该行
        }
    }
}

/// 根视图：承载登录页 / 注册页 / 弹窗 / Toast / 成功遮罩等全局层
struct RootView: View {
    #if DEBUG
    @State private var showRNDevPanel = false
    @State private var pendingLaunch: RNLaunchRequest?
    @State private var rnLaunch: RNLaunchRequest?
    #endif

    var body: some View {
        ZStack {
            LoginView()
            #if DEBUG
            rnDevFloatingButton
            #endif
        }
        #if DEBUG
        .sheet(isPresented: $showRNDevPanel, onDismiss: {
            // 在 sheet 关闭后再弹 fullScreenCover，避免「sheet 未关就 present cover」冲突
            if let p = pendingLaunch {
                rnLaunch = p
                pendingLaunch = nil
            }
        }) {
            RNDevLauncherView { request in
                pendingLaunch = request
                showRNDevPanel = false
            }
        }
        .fullScreenCover(item: $rnLaunch) { request in
            RNContainerView(request: request)
        }
        #endif
    }

    #if DEBUG
    /// DEBUG-only：右下角 RN 调试浮动按钮
    private var rnDevFloatingButton: some View {
        Button {
            showRNDevPanel = true
        } label: {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Theme.gradient)
                .clipShape(Circle())
                .shadow(color: Theme.shadowButton, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rnDevButton")
        .accessibilityLabel("React Native 调试")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }
    #endif
}