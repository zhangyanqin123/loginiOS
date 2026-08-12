# 真机部署与 RN 调试实施计划

> 目标：将 iOSSwiftLogin（SwiftUI 登录页 + DEBUG-only RN 调试入口）安装到 iPhone 真机，用真机调试 RN 工程（MarketCoreRNApp）。
> 日期：2026-08-12

## 背景

集成 RN 调试入口后（`dd0ac17`），模拟器已可零配置调试（`localhost` 直连 Metro）。真机调试需要额外的前置条件：**签名证书、设备信任、Xcode 版本兼容、命令行安装工具**，且 Metro Host 必须用开发机局域网 IP（`localhost` 在真机上指向手机自身）。

## 已核实环境

| 项目 | 状态 |
|---|---|
| Xcode | 14.1（14B47b）→ 真机系统必须 ≤ iOS 16.6.x；**无 devicectl**（Xcode 15+ 才有） |
| 签名 | pbxproj `CODE_SIGN_STYLE = Automatic`、无 `DEVELOPMENT_TEAM`；Xcode 已登录 Apple ID，免费 Personal Team `F5ANQ4H98T`（子朋肖）；本机 0 证书（首次真机构建自动生成） |
| Metro | 已在 `*:8081` 运行（`packager-status:running`），`192.168.61.1:8081/status` 可达，无需重启 |
| 局域网 IP | `192.168.61.1`（en7 以太网口） |
| Info.plist | `NSAllowsLocalNetworking=true` + `NSLocalNetworkUsageDescription` 已就位（ATS 本地网络豁免） |
| 防火墙 | `socketfilterfw --getglobalstate` = disabled，**无需放行 8081** |
| 安装工具 | brew 已装；`ios-deploy`/`ideviceinstaller` 未装（需 `brew install ios-deploy`） |
| RN 代码 | 已支持真机：面板 Metro Host 输入框（白名单校验），`RNDevBridgeDelegate.sourceURL` 用 `request.host` 构造 bundle URL，**无需改代码** |
| build/ | 已存在，无需重跑 `pod install`；hermes-engine universal 含 device arm64 切片 |

## 当前阻塞项

**Mac 在 USB 层完全未检测到 iPhone**：`system_profiler SPUSBDataType` 无 iPhone 设备，`/var/db/lockdown/` 为空（从未配对过）。需先解决线材/端口/信任问题（见 Step 0）。

## 实施步骤

### Step 0（GUI，阻塞项）：让手机出现在 USB 总线并配对

- 换支持数据传输的线、直插 Mac 机身 USB-C 口（避开 Hub）；解锁亮屏状态下插入并点「信任此电脑」
- 弹窗未出现 → 设置→通用→还原→还原位置与隐私 强制重弹，或 `sudo pkill -f usbmuxd`
- 验证：`xcrun xctrace list devices` 的 == Devices == 段出现 iPhone；`ls /var/db/lockdown/` 出现 `<UDID>.plist`
- **必须确认手机 OS ≤ 16.6.x**（Xcode 14.1 硬上限；iOS 17+ 需升级 Xcode 或换机）
- USB 层不可见 = 线/端口问题，无软件可解

### Step 1（CLI）：pbxproj 加 DEVELOPMENT_TEAM

- `iOSLogin/iOSLogin.xcodeproj/project.pbxproj` 的 iOSLogin target Debug/Release 两处 `CODE_SIGN_STYLE = Automatic;` 下各加一行 `DEVELOPMENT_TEAM = F5ANQ4H98T;`
- **UITests target 不加**（scheme BuildAction 只含 iOSLogin，普通 build 不构建 UITests）
- 验证：`plutil -lint project.pbxproj`；`bash scripts/ios-reload.sh deploy` 跑一次模拟器构建确认工程没坏
- 回滚：`git checkout` 两行即回滚，对模拟器构建无副作用

### Step 2（CLI，首次需网络）：真机构建

```bash
cd iOSLogin
xcodebuild -workspace iOSLogin.xcworkspace -scheme iOSLogin \
  -configuration Debug \
  -destination "platform=iOS,id=$UDID" \
  -derivedDataPath build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  build
```

两个 flag 是免费团队自动签名关键（自动建证书/注册设备/生成内部 profile）。

- 验证：产物在 `build/Build/Products/Debug-iphoneos/iOSLogin.app`；`codesign -dv` 显示 TeamIdentifier=F5ANQ4H98T
- 失败降级：Xcode GUI 打开 workspace → Signing & Capabilities 选 team → 真机 Run 一次完成首次签名后再回 CLI；仍失败切 `U3CRBTS8GG`

### Step 3（CLI）：安装 ios-deploy 并部署

```bash
brew install ios-deploy   # 自动拉 libimobiledevice
ios-deploy -i "$UDID" --noninteractive --justlaunch \
  --bundle build/Build/Products/Debug-iphoneos/iOSLogin.app
```

- 失败处理：设备未配对回 Step 0；同 bundle id 旧 app 先 `ios-deploy -i "$UDID" --uninstall_only --bundle_id com.example.iOSLogin` 卸载
- 备选 GUI：Devices and Simulators 拖入 .app；重启不重装：`ios-deploy --justlaunch --noinstall --bundle <app>`

### Step 4（GUI）：手机首次信任

设置 → 通用 → VPN 与设备管理 → Developer App → 信任（不做则点击即闪退）。验证：登录页右下角出现 rnDevButton。

### Step 5（GUI）：RN 真机接线

- 提前验证（装机前即可）：手机 Safari 打开 `http://192.168.61.1:8081/status` 应显示 `packager-status:running`，确认同网段可达
- App 内点 rnDevButton → Metro Host 填 `192.168.61.1`（端口默认 8081）→ 启动；首次 Local Network 弹窗允许（拒绝则去 设置→隐私与安全→本地网络 手动开）
- 验证：Metro 终端出现 `GET /index.bundle?platform=ios&dev=true` 请求日志，app 显示 RN 界面

### Step 6（CLI，可选）：脚本化

新增 `scripts/ios-device.sh`（**不动 ios-reload.sh**：watchman 监听语义对真机不适用，改 RN 代码走 Metro 热更新无需重装）：

```bash
UDID="${DEVICE_UDID:-$(xcrun xctrace list devices 2>/dev/null | awk -F'[()]' '/== Devices ==/{f=1;next} /== Simulators ==/{f=0} f && /\([0-9A-Fa-f-]{36}\)/{print $2; exit}')}"
[ -n "$UDID" ] || { echo "未找到真机（检查 USB/信任）"; exit 1; }
xcodebuild -workspace iOSLogin.xcworkspace -scheme iOSLogin -configuration Debug \
  -destination "platform=iOS,id=$UDID" -derivedDataPath build \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build || exit 1
ios-deploy -i "$UDID" --noninteractive --justlaunch --bundle build/Build/Products/Debug-iphoneos/iOSLogin.app
```

## 风险与回滚

- 免费签名 7 天过期 → 重跑 Step 2+3+4；iOS 17+ 手机 → 必须升级 Xcode；首次签名需网络
- 免费团队设备上限 3 台；同 bundle id 旧 app 先卸载
- 唯一工程改动：pbxproj 两行 `DEVELOPMENT_TEAM`（git 可回滚）；脚本为新增文件（`git rm` 即回滚）

## 验证（端到端）

1. `xcrun xctrace list devices` 出现 iPhone + `ls /var/db/lockdown/` 有 plist（Step 0）
2. 模拟器构建仍通过（Step 1 验证 pbxproj 没坏）
3. 真机构建产物存在 + codesign TeamIdentifier 正确（Step 2）
4. `ios-deploy` 安装后 App 在手机上启动，出现 rnDevButton（Step 3+4）
5. 手机 Safari 访问 `http://192.168.61.1:8081/status` 返回 running（Step 5 预检）
6. App 面板填 `192.168.61.1` 启动 RN 容器，Metro 日志出现 bundle 请求，RN 界面渲染（Step 5）

## 关键文件

- `iOSLogin/iOSLogin.xcodeproj/project.pbxproj`（Step 1 改动点）
- `scripts/ios-device.sh`（Step 6 新增）
- `scripts/ios-reload.sh`（参照，不动）
- `Features/RNDev/RNDevConfig.swift` / `RNDevLauncherView.swift` / `Info.plist`（已就位，无需改）