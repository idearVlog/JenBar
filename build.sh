#!/bin/zsh
# Compila JenBar.app (sin Xcode, sólo con las Command Line Tools).
set -e
cd "$(dirname "$0")"
VERSION=1.0.0
APP=build/JenBar.app
rm -rf build && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
swiftc -O -parse-as-library -target arm64-apple-macos14 Sources/*.swift -o $APP/Contents/MacOS/JenBar
cp Resources/*.svg $APP/Contents/Resources/
cat > $APP/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>JenBar</string>
<key>CFBundleIdentifier</key><string>com.idearvlog.jenbar</string>
<key>CFBundleExecutable</key><string>JenBar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSAppleEventsUsageDescription</key><string>JenBar abre Terminal para vincular Claude o ChatGPT.</string>
<key>NSHumanReadableCopyright</key><string>© 2026 Fabián Fernández · GPL-3.0 · Gentileza de idearVlog y Los Viajes del Tío Fabián</string>
</dict></plist>
EOF
xattr -cr $APP
codesign --force --sign - $APP
echo "Listo: $APP"
