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
