#!/usr/bin/env zsh
# ChargeHub 一键打包脚本
#
# 用法:
#   ./tools/build_ipa.sh                       # 默认: 开发版 IPA (7 天有效, 最适合私下发给朋友)
#   ./tools/build_ipa.sh development          # 同上, 显式指定
#   ./tools/build_ipa.sh adhoc                # Ad Hoc, 1 年有效, 设备需提前登记 UDID
#   ./tools/build_ipa.sh app-store            # App Store / TestFlight, 90 天有效(通过 TestFlight)
#
# 产物位置:
#   ~/Desktop/ChargeHub-Builds/ChargeHub-<version>-<method>-<timestamp>.ipa
#
# 前置条件:
#   - Xcode 已安装, 且命令行工具已配置 (xcode-select -p)
#   - Apple Developer 账号已登录 Xcode
#   - DEVELOPMENT_TEAM 已在 project.pbxproj 配置

set -euo pipefail

# ---- 参数处理 ----------------------------------------------------------
METHOD="${1:-development}"

case "$METHOD" in
    development) EXPORT_METHOD="debugging"  ;;  # Xcode 26 重命名为 debugging
    adhoc)       EXPORT_METHOD="ad-hoc"     ;;
    app-store)   EXPORT_METHOD="app-store"  ;;
    *)
        echo "❌ 未知的导出方式: $METHOD"
        echo ""
        echo "可用方式:"
        echo "  development    开发版, 7 天有效, 最简方案"
        echo "  adhoc          Ad Hoc, 1 年有效, 设备需 UDID"
        echo "  app-store      App Store / TestFlight, 90 天有效(通过 TestFlight)"
        exit 1
        ;;
esac

# ---- 路径与版本 -------------------------------------------------------
SCRIPT_DIR="${0:A:h}"                       # 脚本所在目录
PROJECT_ROOT="${SCRIPT_DIR:h}"              # 项目根目录 (ChargeHub/)
PROJECT_FILE="$PROJECT_ROOT/ChargeHub.xcodeproj"
TARGET="ChargeHub"
SCHEME="ChargeHub"
CONFIGURATION="Release"

if [[ ! -d "$PROJECT_FILE" ]]; then
    echo "❌ 找不到 Xcode 工程: $PROJECT_FILE"
    echo "请在 ChargeHub 项目根目录下运行此脚本。"
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "❌ xcodebuild 不在 PATH 中, 请先安装 Xcode 或运行 xcode-select --install"
    exit 1
fi

# 检测 Scheme 是否存在 (项目里需要勾选 Scheme 共享)
if ! xcodebuild -project "$PROJECT_FILE" -list 2>/dev/null | grep -q "^\s*$SCHEME\s*$"; then
    echo "❌ 项目里找不到 scheme '$SCHEME'."
    echo ""
    echo "   原因: 这个项目里 '$SCHEME' scheme 没有被共享 (Shared)."
    echo "   修复: 在 Xcode 里打开 ChargeHub.xcodeproj,"
    echo "         菜单 Product → Scheme → Manage Schemes..."
    echo "         找到 ChargeHub, 勾选右边的 Shared, 点 Close."
    echo "         然后重新运行本脚本."
    exit 1
fi

# ---- 读取 Marketing Version 与 Build -----------------------------------
INFO_PLIST="$PROJECT_ROOT/ChargeHub/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1")

# 如果 Info.plist 里是 $(MARKETING_VERSION) 这种变量, fallback 到默认值
if [[ "$VERSION" == \$\(* ]]; then
    VERSION="1.0"
fi
if [[ "$BUILD" == \$\(* ]]; then
    BUILD="1"
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="$HOME/Desktop/ChargeHub-Builds"
ARCHIVE_DIR="$OUTPUT_DIR/Archives"
EXPORT_DIR="$OUTPUT_DIR/Export"
ARCHIVE_PATH="$ARCHIVE_DIR/ChargeHub-$VERSION-$BUILD-$TIMESTAMP.xcarchive"
EXPORT_PATH="$EXPORT_DIR/$METHOD-$TIMESTAMP"
IPA_NAME="ChargeHub-$VERSION-$BUILD-$METHOD-$TIMESTAMP.ipa"

mkdir -p "$OUTPUT_DIR" "$ARCHIVE_DIR" "$EXPORT_DIR"

# ---- 临时 ExportOptions.plist ------------------------------------------
EXPORT_OPTIONS_FILE=$(mktemp -t chargehub-export-options.XXXXXX.plist)
trap 'rm -f "$EXPORT_OPTIONS_FILE"' EXIT

cat > "$EXPORT_OPTIONS_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$EXPORT_METHOD</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>compileBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <false/>
</dict>
</plist>
EOF

# ---- 开始 ---------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 ChargeHub 一键打包"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Target:        $TARGET"
echo "  Configuration: $CONFIGURATION"
echo "  Method:        $EXPORT_METHOD"
echo "  Version:       $VERSION ($BUILD)"
echo "  Archive:       $ARCHIVE_PATH"
echo "  Export:        $EXPORT_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ---- 1. Archive --------------------------------------------------------
echo "▶ Step 1/2: Archive (这一步会需要 1-3 分钟)..."
xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=K8PUAS97MN \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    archive \
    2>&1 | tail -40

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "❌ Archive 失败, 请检查上方日志"
    exit 1
fi

# ---- 2. Export IPA ----------------------------------------------------
echo ""
echo "▶ Step 2/2: Export IPA..."
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_FILE" \
    2>&1 | tail -20

# 找到导出的 IPA
IPA_PATH=$(find "$EXPORT_PATH" -maxdepth 2 -name "*.ipa" -type f | head -n 1)

if [[ -z "$IPA_PATH" || ! -f "$IPA_PATH" ]]; then
    echo "❌ 导出 IPA 失败, 请检查上方日志"
    echo "导出目录内容:"
    ls -la "$EXPORT_PATH" || true
    exit 1
fi

# 重命名成更友好的格式
FINAL_IPA="$OUTPUT_DIR/$IPA_NAME"
mv "$IPA_PATH" "$FINAL_IPA"

# ---- 总结 -------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 打包完成!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 IPA 文件: $FINAL_IPA"
echo "📦 Archive:  $ARCHIVE_PATH"
echo ""
echo "📤 分发方式:"

case "$EXPORT_METHOD" in
    development)
        cat <<EOF
   这是开发版 IPA, 7 天有效.
   发送给朋友后, 对方第一次打开需要:
     iOS: 设置 → 通用 → VPN与设备管理 → 信任你的证书
   7 天后需要重新安装.
EOF
        ;;
    ad-hoc)
        cat <<EOF
   这是 Ad Hoc IPA, 1 年有效.
   收件人的设备 UDID 必须已经登记到你的 Apple Developer 账号.
   对方不需要"信任证书"步骤, 直接双击安装即可.
EOF
        ;;
    app-store)
        cat <<EOF
   这是 App Store Connect 用的 IPA, 本身不能直接安装.
   接下来:
     1. 用 Xcode 或 Transporter 上传到 App Store Connect
     2. 在 App Store Connect 后台提交审核
     3. 审核通过后, 通过 TestFlight 分发给测试用户
EOF
        ;;
esac

echo ""
echo "💡 直接打开 Finder 找到 IPA:"
echo "   open '$OUTPUT_DIR'"
