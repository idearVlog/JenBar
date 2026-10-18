#!/bin/zsh
# Compila JenBar.app (sin Xcode, sólo con las Command Line Tools).
set -e
cd "$(dirname "$0")"
VERSION=1.1.0
APP=build/JenBar.app
rm -rf build && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
# Binario universal: Apple Silicon e Intel.
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -target $arch-apple-macos14 Sources/*.swift -o build/JenBar-$arch
done
lipo -create build/JenBar-arm64 build/JenBar-x86_64 -output $APP/Contents/MacOS/JenBar
rm build/JenBar-arm64 build/JenBar-x86_64
cp Resources/*.svg $APP/Contents/Resources/
# Ícono: .icns con todos los tamaños de macOS a partir de Resources/icono-1024.png.
SET=build/JenBar.iconset && mkdir -p $SET
for t in 16 32 128 256 512; do
  sips -z $t $t Resources/icono-1024.png --out $SET/icon_${t}x${t}.png >/dev/null
  sips -z $((t*2)) $((t*2)) Resources/icono-1024.png --out $SET/icon_${t}x${t}@2x.png >/dev/null
done
iconutil -c icns $SET -o $APP/Contents/Resources/JenBar.icns && rm -rf $SET
cat > $APP/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>JenBar</string>
<key>CFBundleIdentifier</key><string>com.idearvlog.jenbar</string>
<key>CFBundleIconFile</key><string>JenBar</string>
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
# Instalador DMG: la app y un acceso a Aplicaciones para arrastrar.
STAGE=build/dmg && mkdir -p $STAGE && cp -R $APP $STAGE/ && ln -s /Applications $STAGE/Aplicaciones
cp $APP/Contents/Resources/JenBar.icns $STAGE/.VolumeIcon.icns
# Se arma en lectura/escritura para marcar el ícono del volumen y después se comprime.
hdiutil create -quiet -volname "JenBar $VERSION" -srcfolder $STAGE -fs HFS+ -format UDRW -ov build/rw.dmg
MNT=$(hdiutil attach -nobrowse -noverify build/rw.dmg | awk -F'\t' '/Volumes/{print $NF}')
SetFile -a C "$MNT" 2>/dev/null || xattr -wx com.apple.FinderInfo "0000000000000000040000000000000000000000000000000000000000000000" "$MNT"
hdiutil detach -quiet "$MNT"
hdiutil convert -quiet build/rw.dmg -format UDZO -ov -o build/JenBar-$VERSION.dmg && rm build/rw.dmg
# El archivo .dmg también muestra el ícono en Finder.
swift -e 'import AppKit; NSWorkspace.shared.setIcon(NSImage(contentsOfFile: CommandLine.arguments[1]), forFile: CommandLine.arguments[2])' Resources/icono-1024.png build/JenBar-$VERSION.dmg
rm -rf $STAGE
echo "Listo: $APP y build/JenBar-$VERSION.dmg"
