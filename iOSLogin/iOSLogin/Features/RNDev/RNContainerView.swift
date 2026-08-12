import SwiftUI
import React

#if DEBUG

// ============================================================
//  RN 全屏容器：RCTBridge + RCTRootView 生命周期、Reload、DevMenu
//  顶部调试栏（返回 / 标题 / Reload / DevMenu）+ RN 视图
// ============================================================

/// 桥 + delegate 强持有者（RCTBridge.delegate 是 weak，必须外部强引用）
final class RNBridgeHandle: ObservableObject {
    let bridge: RCTBridge
    let delegate: RNDevBridgeDelegate

    init(request: RNLaunchRequest) {
        delegate = RNDevBridgeDelegate(request: request)
        bridge = RCTBridge(delegate: delegate, launchOptions: nil)
    }

    deinit { bridge.invalidate() }
}

struct RNContainerView: View {
    let request: RNLaunchRequest
    @StateObject private var handle: RNBridgeHandle
    @Environment(\.dismiss) private var dismiss

    init(request: RNLaunchRequest) {
        self.request = request
        _handle = StateObject(wrappedValue: RNBridgeHandle(request: request))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            RNRootViewController(bridge: handle.bridge, moduleName: request.moduleName)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
            }
            .accessibilityIdentifier("rnDevBackButton")

            Spacer()

            Text("\(request.moduleName)\n\(request.host):\(request.port)")
                .font(Theme.fontMicro)
                .foregroundColor(Theme.text3)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("rnDevTitle")

            Spacer()

            Button("Reload") {
                RCTTriggerReloadCommandListeners("RNDev Reload button")
            }
            .font(Theme.fontCaption)
            .accessibilityIdentifier("rnDevReloadButton")

            Button("DevMenu") {
                // 导入器把 RCTShowDevMenuNotification 重命名为 NSNotification.Name.RCTShowDevMenu
                NotificationCenter.default.post(name: NSNotification.Name.RCTShowDevMenu, object: nil)
            }
            .font(Theme.fontCaption)
            .accessibilityIdentifier("rnDevMenuButton")
        }
        .foregroundColor(Theme.primary)
        .padding(.horizontal, 16)
        .frame(height: 48)
    }
}

/// 为 RN 视图提供 UIViewController 上下文（@react-navigation/native-stack 需要）
struct RNRootViewController: UIViewControllerRepresentable {
    let bridge: RCTBridge
    let moduleName: String

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .white
        let rootView = RCTRootView(bridge: bridge, moduleName: moduleName, initialProperties: nil)
        rootView.backgroundColor = .white
        rootView.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(rootView)
        NSLayoutConstraint.activate([
            rootView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            rootView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            rootView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            rootView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)
        ])
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

/// 桥的 bundle 来源：DEBUG 下始终从 Metro 拉 index.bundle
final class RNDevBridgeDelegate: NSObject, RCTBridgeDelegate {
    let request: RNLaunchRequest

    init(request: RNLaunchRequest) {
        self.request = request
    }

    func sourceURL(for bridge: RCTBridge) -> URL? {
        RNDevConfig.bundleURL(host: request.host, port: request.port, bundleRoot: request.bundleRoot)
    }
}

#endif