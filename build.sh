#!/bin/bash
# Planner 메뉴바 앱을 .app 번들로 빌드한다.
# SwiftPM 매니페스트가 이 환경에서 깨져 있어 swiftc로 직접 컴파일한다.
set -euo pipefail

APP="Planner.app"
BUNDLE_ID="com.local.planner"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macosx14.0"

echo "▶ Cleaning ./$APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

if [ -f icon/AppIcon.icns ]; then
  echo "▶ Adding app icon"
  cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

echo "▶ Compiling Swift sources"
xcrun swiftc \
  -sdk "$SDK" \
  -target "$TARGET" \
  -parse-as-library \
  -O \
  $(find Sources/Planner -name '*.swift') \
  -o "$APP/Contents/MacOS/Planner"

echo "▶ Writing Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Planner</string>
    <key>CFBundleExecutable</key>      <string>Planner</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIconName</key>        <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <!-- Dock 아이콘 없이 메뉴바 전용으로 실행 -->
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
PLIST

echo "▶ Code signing (ad-hoc)"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign 생략됨)"

echo "✅ Done: $APP"
echo "   실행:  open ./$APP   (상단 메뉴바에 체크리스트 아이콘이 생깁니다)"
echo "   종료:  메뉴바 드롭다운의 '종료' 버튼"
