#
//  desktop_renamer.sh
//  Dnamer
//
//  Created by Lia huang on 2/27/26.
//

echo "🔨 Compiling .dylib..."
# Build just the dylib
clang -dynamiclib \
  -arch arm64e \
  -framework Foundation \
  -framework QuartzCore \
  -framework CoreText \
  -framework Cocoa \
  -o desktop_renamer.dylib \
  dr2.m \
  ZKSwizzle.m
  
if [ $? -ne 0 ]; then
    echo "❌ Compilation failed"
    exit 1
fi

echo "✅ Compiled successfully"
echo ""

echo "🧹 Disabling Dock's launchd agent temporarily..."
# Unload Dock from launchd to prevent auto-restart
launchctl unload /System/Library/LaunchAgents/com.apple.Dock.plist 2>/dev/null || true

echo "🚀 Killing existing Dock process..."
killall Dock 2>/dev/null
sleep 1

echo "💉 Injecting inspect.dylib into Dock..."

# Inject into Dock
DYLD_INSERT_LIBRARIES="$(pwd)/desktop_renamer.dylib" /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock &
DOCK_PID=$!

# Wait a moment for Dock to start and log initialization
sleep 2

# Check if Dock is still running
if ps -p $DOCK_PID > /dev/null 2>&1; then
    echo "✅ Dock is running with PID: $DOCK_PID"
else
    echo "❌ ERROR: Dock crashed or exited immediately!"
    echo "   Check crash logs with:"
    echo "   log show --predicate 'processImagePath CONTAINS \"Dock\"' --last 5m --info"
    echo ""
    echo "   This might be caused by:"
    echo "   - SIP (System Integrity Protection) blocking dylib injection"
    echo "   - Code signing issues"
    echo "   - Incompatible dylib"
    echo ""
    echo "🔄 Restoring normal Dock..."
    launchctl load /System/Library/LaunchAgents/com.apple.Dock.plist 2>/dev/null
    exit 1
fi

echo "Restore Dock:"
echo "✅ launchctl stop com.apple.Dock.agent && launchctl start com.apple.Dock.agent"


echo ""
echo "✅ Dock should now be running with inspector injected (PID: $DOCK_PID)"
echo "   Open Mission Control and watch for 🎯 logs!"
echo ""
echo "   To view logs in another terminal, run:"
echo "   log stream --predicate 'processImagePath CONTAINS \"Dock\"' --style compact"
echo ""
echo "   Press Ctrl+C to stop and restore normal Dock"

# Function to restore normal Dock
restore_dock() {
    echo ""
    echo "🔄 Restoring normal Dock..."
    
    # Kill the injected Dock process
    if [ ! -z "$DOCK_PID" ]; then
        kill $DOCK_PID 2>/dev/null
    fi
    killall Dock 2>/dev/null
    
    # Re-enable the launchd agent
    launchctl load /System/Library/LaunchAgents/com.apple.Dock.plist 2>/dev/null
    
    # Give it a moment to restart via launchd
    sleep 1
    
    echo "✅ Normal Dock restored"
    exit 0
}

# Set up trap to call restore function on Ctrl+C
trap restore_dock INT TERM

# Wait for the Dock process to exit (or Ctrl+C)
wait $DOCK_PID

