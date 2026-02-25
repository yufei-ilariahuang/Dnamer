import SwiftUI
import AppKit

struct ContentView: View {
    // State for 6 text fields
    @State private var text1: String = ""
    @State private var text2: String = ""
    @State private var text3: String = ""
    @State private var text4: String = ""
    @State private var text5: String = ""
    @State private var text6: String = ""
    
    // Status message
    @State private var statusMessage: String = ""
    @State private var showStatus: Bool = false
    
    // Focus management
    @FocusState private var focusedField: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Dnamer")
                .font(.title.bold())
            
            Text("Enter text or emoji for each Desktop name")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Divider()
            
            // 6 Text input boxes arranged horizontally
            HStack(spacing: 8) {
                TextInputBox(number: 1, text: $text1, isFocused: focusedField == 1)
                    .focused($focusedField, equals: 1)
                TextInputBox(number: 2, text: $text2, isFocused: focusedField == 2)
                    .focused($focusedField, equals: 2)
                TextInputBox(number: 3, text: $text3, isFocused: focusedField == 3)
                    .focused($focusedField, equals: 3)
                TextInputBox(number: 4, text: $text4, isFocused: focusedField == 4)
                    .focused($focusedField, equals: 4)
                TextInputBox(number: 5, text: $text5, isFocused: focusedField == 5)
                    .focused($focusedField, equals: 5)
                TextInputBox(number: 6, text: $text6, isFocused: focusedField == 6)
                    .focused($focusedField, equals: 6)
            }
            
            // Apply button
            Button(action: applyDesktopNames) {
                Text("Apply Desktop Names")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
            
            // Status message
            if showStatus {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusMessage.contains("Error") ? .red : .green)
                    .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 250)
    }
    
    /// Applies the desktop names using AppleScript
    private func applyDesktopNames() {
        let names = [text1, text2, text3, text4, text5, text6]
        
        // Build AppleScript to rename desktops
        var script = """
        tell application "System Events"
            tell application process "Dock"
        """
        
        for (index, name) in names.enumerated() where !name.isEmpty {
            let desktopNumber = index + 1
            // Escape quotes in the name
            let escapedName = name.replacingOccurrences(of: "\"", with: "\\\"")
            script += """
            
                try
                    set value of static text 1 of group \(desktopNumber) of list 1 to "\(escapedName)"
                end try
            """
        }
        
        script += """
        
            end tell
        end tell
        """
        
        // Execute the AppleScript
        executeAppleScript(script)
    }
    
    /// Executes an AppleScript string
    private func executeAppleScript(_ script: String) {
        var error: NSDictionary?
        
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                statusMessage = "Error: \(error[NSAppleScript.errorMessage] ?? "Unknown error")"
                showStatus = true
                print("AppleScript Error: \(error)")
            } else {
                statusMessage = "✅ Desktop names applied successfully!"
                showStatus = true
                print("AppleScript executed successfully: \(output)")
                
                // Hide success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showStatus = false
                }
            }
        } else {
            statusMessage = "Error: Failed to create AppleScript"
            showStatus = true
        }
    }
}

/// A reusable box component for text input
struct TextInputBox: View {
    let number: Int
    @Binding var text: String
    var isFocused: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            // Number label
            Text("\(number)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            
            // Text field with improved interaction
            TextField("", text: $text, prompt: Text("Desktop \(number)").foregroundColor(.gray.opacity(0.5)))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .frame(width: 80, height: 28)
        }
    }
}

#Preview {
    ContentView()
}
