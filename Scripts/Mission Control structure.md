

## Architecture Overview

### System Flow (Mission Control Activation)

```
User triggers Mission Control (Ctrl+Up)
    ↓
[com.apple.dock:windowmanager] Acquiring control for .missionControl
    ↓
[com.apple.windowmanager:xpc] Requests layout control from WindowManager
    ↓
[com.apple.wallpaper:dock] Returns desktop window for each space (UUID-based)
    ↓
[com.apple.wallpaper:dock] Returns snapshot-backed miniLayer per window
    ↓
(inspect.dylib) Hook intercepts text rendering ← YOUR INJECTION POINT
    ↓
[com.apple.dock:missioncontrol] Mode: .none → .showAllWindows
    ↓
Desktop names rendered via ECTextLayer.setString:
```

---

### Plits Storage
```
User installs plugin
        ↓
Plugin loads in Dock
        ↓
initialize() runs
        ↓
createDefaultPlistIfNeeded() checks:
   Does ~/Library/Preferences/com.dnamer.desktopnames.plist exist?
        ↓
   NO → Creates it with default names
   YES → Uses existing one
        ↓
Mission Control opened
        ↓
loadCustomNames() reads the plist
        ↓
Desktop names displayed

```

## Key Classes & Methods

### **CATextLayer (Foundation)**
- **Superclass**: `CALayer` (Core Animation)
- Base text rendering layer

### **ECTextLayer (Dock Internal)**
- **Superclass**: `CATextLayer` 
- **Function**: Renders desktop/window names in Mission Control
- **Hook Target**: `-setString:` method
  - Called when text needs to be displayed
  - Receives: `NSString` or `NSAttributedString`
  - Renders: Desktop names, app titles, space labels

### **Injection Flow**

```objc
__attribute__((constructor)) onLoad()
  └─> Find ECTextLayer class (runtime lookup)
      └─> Hook -setString: method
          └─> Intercept original string
              └─> Check if matches desktop/app name
                  └─> Replace with custom emoji name
                      └─> Call original implementation
```

---

## Mission Control Render Pipeline

1. **Space Enumeration** (UUIDs)
   - Desktop 1: `5A24804D-E463-4D2A-8EA0-C825EC86E43E`
   - Desktop 2: `D6E4CD00-0783-48FA-9D69-A97DD48F283C`
   - Desktop 3: `37F6FB03-3C30-4ADC-9426-D4178445CB6F`

2. **Window Creation**
   - Each space gets a `desktop window` + `snapshot-backed miniLayer`
   - Window IDs: `c8`, `c9`, `ca` (hex)

3. **Text Rendering** ← **Injection happens here**
   - `ECTextLayer.setString:` called for each label
   - Original: "Desktop 1" → Hooked: "🏠 Home"

4. **Display**
   - Mission Control shows customized names

---

## Quick Commands

```bash
# Run the injector
./inspect.sh

# Watch logs in real-time
log stream --predicate 'processImagePath CONTAINS "Dock"' --style compact

# Manual Dock restore (if script fails)
launchctl stop com.apple.Dock.agent && launchctl start com.apple.Dock.agent

```

