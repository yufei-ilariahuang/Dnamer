#!/bin/bash
#
#  build_bundle.sh
#  Dnamer
#
#  Created by Lia huang on 2/26/26.
#
#  Builds a MacForge-compatible bundle for Desktop Renamer
#

set -e  # Exit on error

BUNDLE_NAME="DesktopRenamer.bundle"
BUILD_DIR="build"
BUNDLE_PATH="$BUILD_DIR/$BUNDLE_NAME"
CONTENTS_DIR="$BUNDLE_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "🏗️  Building Desktop Renamer MacForge Bundle"
echo "=============================================="
echo ""

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    echo "🧹 Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

# Create bundle directory structure
echo "📁 Creating bundle structure..."
mkdir -p "$MACOS_DIR"

# Compile the dylib
echo "🔨 Compiling desktop_renamer.dylib..."
clang -dynamiclib \
  -arch arm64 \
  -arch x86_64 \
  -framework Foundation \
  -framework QuartzCore \
  -framework CoreText \
  -framework Cocoa \
  -fmodules \
  -fobjc-arc \
  -o "$MACOS_DIR/DesktopRenamer" \
  desktop_renamer.m \
  ZKSwizzle.m

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed"
    exit 1
fi

echo "✅ Compiled successfully"

# Copy Info.plist
echo "📋 Copying Info.plist..."
cp Info.plist "$CONTENTS_DIR/Info.plist"

# Display bundle structure
echo ""
echo "📦 Bundle structure:"
find "$BUNDLE_PATH" -print | sed -e "s;$BUILD_DIR/;;g" | sed -e 's;[^/]*/; |-- ;g'

echo ""
echo "✅ Bundle created successfully!"
echo ""
echo "📍 Bundle location: $BUNDLE_PATH"
echo ""
echo "🚀 To install with MacForge:"
echo "   1. Open MacForge"
echo "   2. Click 'Install Plugin...'"
echo "   3. Select: $BUNDLE_PATH"
echo ""
echo "   OR copy manually:"
echo "   cp -r $BUNDLE_PATH ~/Library/Application\\ Support/MacEnhance/Plugins/"
echo ""
echo "🔄 After installation, restart Dock:"
echo "   killall Dock"
echo ""
