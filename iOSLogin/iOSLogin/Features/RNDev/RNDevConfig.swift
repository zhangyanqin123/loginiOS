import Foundation
import React

#if DEBUG

// ============================================================
//  RN 调试配置与工具（DEBUG only）
//  配置：Metro 地址 / 默认 AppName / URL 构造 / 连通性探测
// ============================================================

enum RNDevConfig {
    /// AppRegistry 注册名（MarketCoreRNApp 工程 index.js 里 registerComponent 的名字）
    static let defaultModuleName = "MarketCoreRNApp"
    /// Metro 入口文件名（MarketCoreRNApp 的 metro 默认入口 index.js）
    static let defaultBundleRoot = "index"
    static let defaultPort = 8081
    /// Metro 默认 host：模拟器连本机 localhost；真机在面板里填开发机局域网 IP
    static let defaultHost = "localhost"

    static let defaultsKeyModuleName = "rnDev.moduleName"
    static let defaultsKeyPort = "rnDev.port"
    static let defaultsKeyHost = "rnDev.host"

    /// 构造 Metro bundle URL：http://<host>:<port>/<root>.bundle?platform=ios&dev=true
    static func bundleURL(host: String = defaultHost, port: Int, bundleRoot: String = defaultBundleRoot) -> URL? {
        var c = URLComponents()
        c.scheme = "http"
        c.host = host
        c.port = port
        c.path = "/\(bundleRoot).bundle"
        c.queryItems = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "dev", value: "true")
        ]
        return c.url
    }

    /// 阻塞式探测 Metro /status（内部信号量同步），必须在后台线程调用
    static func isMetroRunning(host: String = defaultHost, port: Int) -> Bool {
        RCTBundleURLProvider.isPackagerRunning("\(host):\(port)", scheme: "http")
    }
}

/// 容器启动参数（调试面板 sheet → 全屏容器 fullScreenCover 传递）
struct RNLaunchRequest: Identifiable {
    let id = UUID()
    let moduleName: String
    let port: Int
    var host: String = RNDevConfig.defaultHost
    var bundleRoot: String = RNDevConfig.defaultBundleRoot
}

#endif