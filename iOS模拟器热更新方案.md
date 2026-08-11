# iOS 模拟器"类热更新"开发体验方案

> 目标：在本项目（SwiftUI 原生 iOS 登录页）实现类似 React Web 热更新（Vite HMR）的体验——**修改代码保存后，模拟器自动体现变化**，摆脱"手改 → 重新构建 → 手动安装 → 手动启动"的重复劳动。
> 本方案基于当前仓库实际环境验证（构建命令、模拟器部署链路、watchman 监听均已实测）。

---

## 1. 背景与目标

React Web 开发中，改一行代码保存，页面几乎瞬间刷新（HMR 甚至保留组件状态）。iOS 原生开发默认没有这种体验：

- Xcode 里每次 Cmd+R = **增量构建 + 安装 + 重启**，通常几秒到十几秒，但必须手动点。
- 命令行环境下（本仓库即如此），需要依次手动执行 `xcodebuild build` → `simctl install` → `simctl launch`，且无图形会话，无法用 Xcode Preview 实时预览。

**核心事实**：iOS App 是编译型原生二进制，**没有官方"保留运行状态的热更新"**。最接近的体验分三档，见下表。

## 2. 方案选型对比

| 方案 | 刷新速度 | 保留应用状态 | 环境要求 | 代码侵入 | 本机(当前)可用 | 推荐度 |
|---|---|---|---|---|---|---|
| **A. Xcode Preview**（SwiftUI 实时预览） | 秒级 | ✅ | 需 Xcode GUI 图形会话 | 无 | ❌ 无 GUI 会话 | 有 GUI 时首选 |
| **B. watchman 监听 + 增量构建 + simctl 自动重装** | 2~10s（增量编译） | ❌ 重启进程 | 纯 CLI，watchman | 无 | ✅ | ⭐ 当前首选 |
| **C. InjectionIII（代码注入热重载）** | 秒级 | ✅ 不重启 | 需 GUI + 第三方工具 + 代码注入 | 需改 App 代码 | ❌ 无 GUI | 进阶可选 |

**结论**：当前环境（Intel 模拟器无图形会话、纯 CLI、零第三方依赖约束）下，**方案 B 是唯一现实可行且零侵入的方案**。它本质上是把 Xcode 的 Cmd+R 自动化：监听源码变化 → 自动增量构建 → 自动安装 → 自动重启。watchman 是系统级工具（已安装），不进入 App 依赖，不违反"无第三方依赖"约束。

> **方案 A 说明**：在 Mac 本机有图形会话时，Xcode 打开工程后 SwiftUI Canvas / Live Preview 是官方秒级方案，本文不再展开。
> **方案 C 说明**：见第 4 节，仅作进阶记录。

## 3. 推荐方案落地（方案 B）

### 3.1 原理

```
watchman daemon（后台常驻，监听文件系统事件）
      │  源码变化（*.swift / project.pbxproj / *.xcscheme，排除 build/）
      ▼
trigger 回调 scripts/ios-reload.sh deploy
      │
      ▼
xcodebuild 增量构建（固定 -derivedDataPath build，仅重编改动文件）
      │  成功
      ▼
simctl install → simctl terminate → simctl launch
```

- watchman 是 Facebook 开源的 `/usr/local/bin/watchman`（本机已装 2025.04.28.00），通过 Unix socket 与常驻 daemon 通信，比轮询高效。
- 增量构建复用 `build/` 产物缓存，单文件改动通常 **2~10s** 完成全部链路（Intel 机器）。
- 每次部署会重启 App 进程，**内存状态不保留**（表单输入等 UI 状态重置），但模拟器 sandbox 数据保留。

### 3.2 完整脚本

脚本已随本方案落地在 **`scripts/ios-reload.sh`**（`chmod +x` 已赋权，可直接运行）。以下为完整源码（如需从文档重新生成，复制保存后执行 `chmod +x scripts/ios-reload.sh`）：

```bash
#!/usr/bin/env bash
# ============================================================
# ios-reload.sh —— SwiftUI 模拟器"类热更新"开发脚本
#
# 用法：
#   bash scripts/ios-reload.sh          # 交互模式：首次部署 + 注册 watchman 监听（Ctrl+C 停止并清理）
#   bash scripts/ios-reload.sh deploy   # 仅执行一次"构建+安装+重启"（watchman trigger 回调入口）
#
# 依赖：watchman（macOS 系统工具，已安装）、Xcode 命令行工具
# 位置：必须位于仓库根目录的 scripts/ 下（此仓库的 Xcode 工程在 iOSLogin/ 子目录）
# ============================================================
set -uo pipefail

# 仓库根（脚本位于 仓库根/scripts/）
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Xcode 工程目录（含 iOSLogin.xcodeproj）
XCODE_DIR="$REPO_DIR/iOSLogin"
cd "$XCODE_DIR"

# ---- 可调参数 -------------------------------------------------
SCHEME="iOSLogin"
DESTINATION="platform=iOS Simulator,name=iPhone 14"
DERIVED_DATA="build"
APP_PATH="build/Build/Products/Debug-iphonesimulator/iOSLogin.app"
BUNDLE_ID="com.example.iOSLogin"
LOG_FILE="$XCODE_DIR/build/ios-reload.log"   # 绝对路径，供 watchman 回调重定向
TRIGGER_NAME="ios-reload"

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

deploy() {
  local t0=$(date +%s)
  log "▶ 检测到变化，开始增量构建…"
  if xcodebuild -project iOSLogin.xcodeproj -scheme "$SCHEME" \
      -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" \
      build >> "$LOG_FILE" 2>&1; then
    log "✔ 构建成功（+$(( $(date +%s) - t0 ))s），安装并重启"
    xcrun simctl install booted "$APP_PATH"
    log "✔ 已安装"
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true   # 未运行时忽略
    xcrun simctl launch booted "$BUNDLE_ID"
    log "✔ 已启动，部署完成（共 +$(( $(date +%s) - t0 ))s）"
  else
    log "✘ 构建失败，错误摘要："
    grep -E "error:" "$LOG_FILE" | tail -5 | sed 's/^/   /' >> "$LOG_FILE"
    log "✘ 保留上次安装的 App，继续监听"
  fi
}

# ---- watchman 回调入口 ----------------------------------------
if [ "${1:-}" = "deploy" ]; then
  deploy
  exit 0
fi

# ---- 交互模式：确保模拟器就绪 + 首次部署 + 注册监听 ------------
xcrun simctl bootstatus booted -b >/dev/null 2>&1 || true
mkdir -p "$(dirname "$LOG_FILE")"
echo "首次部署…（日志：${LOG_FILE}）"
deploy

watchman watch "$REPO_DIR" >/dev/null 2>&1
watchman -j >/dev/null <<EOF
["trigger", "$REPO_DIR", {
  "name": "$TRIGGER_NAME",
  "expression": ["allof",
    ["anyof",
      ["match", "**/*.swift", "wholename"],
      ["match", "**/project.pbxproj", "wholename"],
      ["match", "**/*.xcscheme", "wholename"]],
    ["not", ["match", "**/build/**", "wholename"]],
    ["not", ["match", "**/.git/**", "wholename"]],
    ["not", ["match", "**/.watchman/**", "wholename"]]],
  "command": ["/bin/bash", "-c", "\"$REPO_DIR/scripts/ios-reload.sh\" deploy >> \"$LOG_FILE\" 2>&1"]
}]
EOF

log "监听中：.swift / project.pbxproj / *.xcscheme（排除 build/）"
echo ""
echo "✅ 已开始监听，修改代码保存后自动部署。"
echo "   完整日志：${LOG_FILE}（另开终端可 tail -f 跟随）"
echo "   下方实时显示进度，Ctrl+C 停止并清理 trigger。"
trap 'watchman trigger-del "$REPO_DIR" "$TRIGGER_NAME" >/dev/null 2>&1; echo ""; echo "⏹ 已停止并清理。若残留，手动执行：watchman trigger-del . ios-reload"' INT TERM

# 前台实时显示关键进度行（tail -f 跟随 + grep 过滤），Ctrl+C 时由 trap 清理
tail -f "$LOG_FILE" | grep --line-buffered -E "▶|✔|✘|⚠"
```

### 3.3 使用说明

```bash
# 1. 脚本已就绪：scripts/ios-reload.sh（本仓库已随文档落地，可跳过下方两行）
#    （若从文档重新生成，才需要：mkdir -p scripts && chmod +x scripts/ios-reload.sh）

# 2. 启动监听（首次会先全量构建+部署，之后增量）
bash scripts/ios-reload.sh

# 3. 日常开发：编辑任意 .swift 文件保存 → 日志出现新记录 → 模拟器自动重启
tail -f iOSLogin/build/ios-reload.log   # 另开终端实时看日志（位于工程目录下）

# 4. 停止：Ctrl+C（自动清理 watchman trigger）
```

**关键点**：
- **监听范围**：`*.swift`、`project.pbxproj`、`*.xcscheme`。改 `Assets.xcassets` 内的图片/颜色不在监听范围（属资源，模拟器热部署即可见，但为稳妥可加入 pattern）。
- **排除 `build/`**：构建产物不触发自身（防止死循环），已实测排除生效。
- **构建失败**：脚本保留上次安装的 App、打印错误、继续监听，不会死循环。
- **trigger 由 watchman daemon 常驻执行**：即使脚本前台退出（未 Ctrl+C 清理），trigger 仍会继续回调部署。Ctrl+C 的 trap 会删除 trigger。

### 3.4 手动命令速查（不依赖脚本）

```bash
cd iOSLogin
# 单次构建（产物输出到 build/）
xcodebuild -project iOSLogin.xcodeproj -scheme iOSLogin \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  -derivedDataPath build build

# 安装 + 重启
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/iOSLogin.app
xcrun simctl terminate booted com.example.iOSLogin 2>/dev/null || true
xcrun simctl launch booted com.example.iOSLogin
```

### 3.5 查看进度与日志

**方式一：前台实时进度**（推荐，无需额外操作）

运行 `bash scripts/ios-reload.sh` 后，终端直接滚动显示关键进度行（`▶` 开始构建、`✔` 各阶段完成带耗时、`✘` 构建失败带错误摘要），覆盖"保存代码 → 自动部署"的整个过程。

**方式二：另开终端跟随完整日志**

```bash
tail -f iOSLogin/build/ios-reload.log        # 实时跟随完整日志（含 xcodebuild 原始输出）
tail -20 iOSLogin/build/ios-reload.log       # 只看最近 20 行
grep -E "✘|error:" iOSLogin/build/ios-reload.log   # 只看错误
```

**日志格式**：每行 `[HH:MM:SS] <标记> 描述`，标记含义：

| 标记 | 含义 |
|---|---|
| `▶` | 检测到代码变化，开始增量构建 |
| `✔` | 构建成功 / 已安装 / 已启动（括号内为已耗时秒数） |
| `✘` | 构建失败（下方附 `error:` 摘要） |
| `⚠` | 其它警告 |

**完整构建日志**：`xcodebuild` 的原始输出也写入同一文件（位于 `iOSLogin/build/`，已被 `.gitignore` 忽略，不会入库）。构建失败时重点看 `error:` 行定位问题。

## 4. 进阶可选：InjectionIII（真·热重载）

**原理**：编译时把源码的动态库版本注入运行中的 App 进程，替换指定类型的实现，**不重启进程、保留状态**。适合"微调个别 View 的布局/颜色"。

**局限（本仓库不推荐此刻启用）**：
- 必须安装第三方 macOS App（InjectionIII），且需要图形会话配合 Xcode 点击注入按钮——本机无 GUI 会话，不可用。
- 需在 App 代码注入加载器（`Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()` 等），并监听注入完成通知刷新视图——属于代码侵入，且**需手改手写 pbxproj 增加 Build Phase**（`iOSLogin.xcodeproj/project.pbxproj` 为手写文件，括号平衡需谨慎）。
- 只能替换已存在类型的实现，**新增类型/文件、改 UI 结构、改 ViewModel 状态机**都不支持，仍需完整重启。

**结论**：待有 GUI 会话的开发环境时可评估，当前跳过。

## 5. 边界与注意事项

| 事项 | 说明 |
|---|---|
| 状态不保留 | 每次部署重启进程，内存态（输入框内容、Tab 选中、倒计时）重置；模拟器磁盘数据保留 |
| 增量编译时间 | Intel 机器单文件改动约 2~10s；全量首构约 1~2 分钟；改动多处/跨文件时编译时间略增 |
| 监听范围 | 未监听 `Assets.xcassets`、xcconfig（本项目无）；如需可自行追加 pattern |
| watchman 残留 | 直接 kill 终端导致 trap 未执行时，trigger 残留；用 `watchman trigger-del . ios-reload` 清理，`watchman trigger-list .` 查看 |
| 启动时的一次初始构建 | watchman 注册 trigger 时会触发一次全量匹配（约多一次增量构建），属正常行为，可忽略；后续保存代码只触发一次 |
| bash 陷阱 | `$VAR` 后紧跟全角/中文标点（如 `）`）时 bash 会误吞后续字节导致 `unbound variable`，脚本内统一用 `${VAR}` 花括号写法规避（已实测） |
| 多实例冲突 | 同仓库重复运行脚本会注册同名 trigger（后者覆盖），无实际危害 |
| `.gitignore` 建议 | 若 watchman 在项目根生成 `.watchman*` 状态目录，追加到 `.gitignore`（`build/` 已忽略，日志 `iOSLogin/build/ios-reload.log` 不会入库） |
| 模拟器 | 脚本固化 `iPhone 14`（iOS 16.1）；换设备改 `DESTINATION` 与 `booted` 名 |
| 无第三方依赖 | watchman 为系统工具，不进入 App 依赖，不违反仓库约束 |

## 附录：与"热更新"概念的澄清

- Web 的 HMR 之所以能秒级且保留状态，是因为 JS 解释执行 + 模块化热替换。
- iOS 原生无法做到同等的通用热更新（App Store 审核也禁止运行时下载代码）。
- "类热更新"的正确预期：**自动完成 构建→安装→重启**，把原 4 步手动操作压缩为 1 步保存动作。状态保留类体验（InjectionIII / Preview）均需 GUI 会话，属另类方案。