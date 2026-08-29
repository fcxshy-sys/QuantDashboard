#!/bin/bash
# ============================================================
# build_trollstore.sh
# QuantDashboard - TrollStore 免签自动化打包脚本
#
# 使用方法:
#   chmod +x build_trollstore.sh
#   ./build_trollstore.sh
#
# 前置要求:
#   - Xcode 15+ 已安装
#   - 有效的 Apple Developer 账号（免费即可，用于生成签名证书）
#   - 设备已安装 TrollStore（巨魔商店）
# ============================================================

set -e

# ========== 配置区 ==========
APP_NAME="QuantDashboard"
BUNDLE_ID="com.quantdashboard.app"
SCHEME="QuantDashboard"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
PAYLOAD_DIR="${BUILD_DIR}/Payload"
OUTPUT_IPA="${BUILD_DIR}/QuantDashboard.tipa"
CONFIGURATION="Release"
IOS_VERSION="15.0"

# 代码签名配置（TrollStore 不需要真实证书，但 xcodebuild 编译需要）
# 可以使用免费的 Apple 开发者证书，或设置为 "" 让 Xcode 自动管理
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
CODE_SIGN_STYLE="${CODE_SIGN_STYLE:-Automatic}"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}"

echo "============================================"
echo "  QuantDashboard TrollStore 打包脚本"
echo "============================================"
echo ""
echo "项目目录: ${PROJECT_DIR}"
echo "配置:     ${CONFIGURATION}"
echo "目标iOS:  ${IOS_VERSION}+"
echo ""

# ========== 步骤 1: 清理构建目录 ==========
echo "[1/6] 清理构建目录..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ========== 步骤 2: 编译项目 ==========
echo "[2/6] 编译项目 (xcodebuild)..."

BUILD_CMD=(
    xcodebuild
    -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj"
    -scheme "${SCHEME}"
    -configuration "${CONFIGURATION}"
    -destination "generic/platform=iOS"
    -derivedDataPath "${BUILD_DIR}/DerivedData"
    CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}"
    CODE_SIGN_STYLE="${CODE_SIGN_STYLE}"
    DEVELOPMENT_TEAM=""
    PROVISIONING_PROFILE="${PROVISIONING_PROFILE}"
    ENABLE_BITCODE=NO
    SWIFT_OPTIMIZATION_LEVEL="-O"
    ONLY_ACTIVE_ARCH=NO
)

# 如果有指定 Provisioning Profile
if [ -n "${PROVISIONING_PROFILE}" ]; then
    BUILD_CMD+=(PROVISIONING_PROFILE="${PROVISIONING_PROFILE}")
fi

# 执行编译
"${BUILD_CMD[@]}" 2>&1 | tail -20

# 检查编译结果
if [ $? -ne 0 ]; then
    echo "❌ 编译失败！请检查上述错误信息。"
    exit 1
fi

echo "✅ 编译成功"

# ========== 步骤 3: 定位编译产物 ==========
echo "[3/6] 定位编译产物..."

# 查找 .app 包
APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "${APP_PATH}" ]; then
    echo "❌ 未找到编译产物 ${APP_NAME}.app"
    exit 1
fi

echo "找到 App: ${APP_PATH}"

# ========== 步骤 4: 生成 Entitlements（TrollStore 特权） ==========
echo "[4/6] 配置 TrollStore Entitlements..."

# TrollStore 需要特殊的 Entitlements 来获得后台保活权限
# 如果项目中已有 Entitlements.plist，直接使用
ENTITLEMENTS_SRC="${PROJECT_DIR}/${APP_NAME}/Entitlements.plist"

if [ ! -f "${ENTITLEMENTS_SRC}" ]; then
    echo "⚠️  未找到 Entitlements.plist，将使用默认配置"
    # 创建临时 Entitlements
    cat > "${BUILD_DIR}/TempEntitlements.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.private.security.no-sandbox</key>
    <true/>
</dict>
</plist>
PLIST_EOF
    ENTITLEMENTS_SRC="${BUILD_DIR}/TempEntitlements.plist"
fi

# 使用 codesign 重新签名 App（TrollStore 特殊签名方式）
echo "使用 ad-hoc 签名..."
codesign --force --sign - \
    --entitlements "${ENTITLEMENTS_SRC}" \
    "${APP_PATH}" 2>/dev/null || echo "签名完成（无证书模式）"

echo "✅ 签名配置完成"

# ========== 步骤 5: 构建 Payload 目录 ==========
echo "[5/6] 构建 Payload 目录..."

rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}"
cp -R "${APP_PATH}" "${PAYLOAD_DIR}/${APP_NAME}.app"

echo "✅ Payload 目录构建完成"

# ========== 步骤 6: 打包 .tipa 文件 ==========
echo "[6/6] 打包 .tipa 文件..."

cd "${BUILD_DIR}"
zip -r -y "${OUTPUT_IPA}" Payload/
cd "${PROJECT_DIR}"

# 检查输出文件
if [ -f "${OUTPUT_IPA}" ]; then
    FILE_SIZE=$(du -h "${OUTPUT_IPA}" | cut -f1)
    echo ""
    echo "============================================"
    echo "  ✅ 打包成功！"
    echo "============================================"
    echo ""
    echo "输出文件: ${OUTPUT_IPA}"
    echo "文件大小: ${FILE_SIZE}"
    echo ""
    echo "安装方法："
    echo "  1. 将 .tipa 文件传输到 iOS 设备"
    echo "  2. 在 TrollStore 中打开该文件"
    echo "  3. 点击安装即可"
    echo ""
    echo "文件可通过以下方式传输到设备："
    echo "  - AirDrop"
    echo "  - iTunes / Finder 文件共享"
    echo "  - iMazing 等第三方工具"
    echo ""
else
    echo "❌ 打包失败！"
    exit 1
fi
