#!/bin/bash
# 用法：
#   ./build.sh          构建本机版本并启动（开发用）
#   ./build.sh release  构建通用版本（Apple 芯片 + Intel），打包成 Tomaboo.zip
set -euo pipefail
cd "$(dirname "$0")"
APP=Tomaboo.app
MODE="${1:-dev}"

if [[ "$MODE" == "release" ]]; then
    # 命令行工具不支持一次多架构，分别构建再用 lipo 合并
    for arch in arm64 x86_64; do
        swift build -c release --triple "$arch-apple-macosx14.0"
    done
    BIN=.build/Tomaboo-universal
    lipo -create -output "$BIN" .build/arm64-apple-macosx/release/Tomaboo .build/x86_64-apple-macosx/release/Tomaboo
else
    swift build -c release
    BIN=.build/release/Tomaboo
    pkill -x Tomaboo || true
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Tomaboo"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

if [[ "$MODE" == "release" ]]; then
    rm -f Tomaboo.zip
    ditto -c -k --keepParent "$APP" Tomaboo.zip
    echo "已生成 Tomaboo.zip"
else
    open "$APP"
fi
