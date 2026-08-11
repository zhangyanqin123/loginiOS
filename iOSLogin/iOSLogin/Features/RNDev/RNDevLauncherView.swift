import SwiftUI

#if DEBUG

// ============================================================
//  RN 调试面板：输入 AppName（AppRegistry 注册名）+ Metro 端口
//  启动前在后台线程探测 Metro /status，未启动则 Toast 提示
// ============================================================

struct RNDevLauncherView: View {
    let onLaunch: (RNLaunchRequest) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var moduleName: String
    @State private var port: String
    @State private var isLaunching = false
    @State private var toast: ToastMessage?

    init(onLaunch: @escaping (RNLaunchRequest) -> Void) {
        self.onLaunch = onLaunch
        let d = UserDefaults.standard
        let savedName = d.string(forKey: RNDevConfig.defaultsKeyModuleName)
        let savedPort = d.object(forKey: RNDevConfig.defaultsKeyPort) as? Int
        _moduleName = State(initialValue: savedName ?? RNDevConfig.defaultModuleName)
        _port = State(initialValue: String(savedPort ?? RNDevConfig.defaultPort))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            InputField(icon: "app.badge.fill",
                       title: "AppName",
                       placeholder: "AppRegistry 注册名",
                       text: $moduleName,
                       maxLength: 64)
                .padding(.top, 24)
            InputField(icon: "number",
                       title: "端口",
                       placeholder: "8081",
                       text: $port,
                       keyboardType: .numberPad,
                       maxLength: 5)
                .padding(.top, Theme.fieldSpacing)
            PrimaryButton(title: isLaunching ? "检测中…" : "启动",
                          state: isLaunching ? .disabled : .enabled,
                          action: launch)
                .padding(.top, 32)
                .accessibilityIdentifier("rnDevLaunchButton")
            Spacer(minLength: 0)
        }
        .padding(Theme.pagePadding)
        .background(Theme.bg)
        .toast($toast)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("RN 调试")
                .font(Theme.fontTitle)
                .foregroundColor(Theme.text1)
            Spacer()
            Button("关闭") { dismiss() }
                .font(Theme.fontCaption)
                .foregroundColor(Theme.text3)
                .accessibilityIdentifier("rnDevCloseButton")
        }
    }

    private func launch() {
        let name = moduleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            toast = ToastMessage(text: "AppName 不能为空", type: .error)
            return
        }
        guard let portInt = Int(port), (1...65535).contains(portInt) else {
            toast = ToastMessage(text: "端口需为 1-65535 的整数", type: .error)
            return
        }
        UserDefaults.standard.set(name, forKey: RNDevConfig.defaultsKeyModuleName)
        UserDefaults.standard.set(portInt, forKey: RNDevConfig.defaultsKeyPort)
        isLaunching = true
        Task {
            // isPackagerRunning 内部信号量阻塞，放后台线程探测
            let running = await Task.detached(priority: .userInitiated) {
                RNDevConfig.isMetroRunning(port: portInt)
            }.value
            await MainActor.run {
                isLaunching = false
                if running {
                    onLaunch(RNLaunchRequest(moduleName: name, port: portInt))
                } else {
                    toast = ToastMessage(text: "Metro 未启动（localhost:\(portInt)），请先 npx react-native start",
                                         type: .error)
                }
            }
        }
    }
}

#endif