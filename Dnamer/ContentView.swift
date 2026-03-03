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
    
    // Plist path
    let plistPath = NSHomeDirectory() + "/Library/Preferences/com.dnamer.desktopnames.plist"

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
        .onAppear {
            loadDesktopNames()
        }
    }
    
    /// Applies the desktop names by saving to plist and notifying the injected code
    private func applyDesktopNames() {
        let names = [text1, text2, text3, text4, text5, text6]
        
        print("📝 Attempting to save names: \(names)")
        print("📍 Plist path: \(plistPath)")
        
        do {
            // Ensure the directory exists
            let url = URL(fileURLWithPath: plistPath)
            let directory = url.deletingLastPathComponent()
            
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("📁 Created directory: \(directory.path)")
            }
            
            // Write as property list XML format
            let plistData = try PropertyListSerialization.data(
                fromPropertyList: names,
                format: .xml,
                options: 0
            )
            
            try plistData.write(to: url, options: .atomic)
            
            print("✅ Saved desktop names to plist")
            print("📄 File size: \(plistData.count) bytes")
            
            // Verify the write by reading back
            if let verifyArray = NSArray(contentsOfFile: plistPath) as? [String] {
                print("✅ Verified plist contents: \(verifyArray)")
                
                if verifyArray == names {
                    print("✅ Verification successful - data matches!")
                } else {
                    print("⚠️ Warning: Saved data doesn't match input")
                }
            } else {
                print("⚠️ Warning: Could not verify plist after writing")
            }
            
            // Send distributed notification to reload names
            DistributedNotificationCenter.default().post(
                name: Notification.Name("com.dnamer.reloadDesktopNames"),
                object: nil
            )
            print("📡 Sent reload notification")
            
            statusMessage = "✅ Desktop names saved!\nPath: \(plistPath)\nOpen Mission Control to see changes."
            showStatus = true
            
            // Hide success message after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showStatus = false
            }
            
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
            showStatus = true
            print("❌ Failed to save plist: \(error)")
            print("❌ Error details: \(error)")
        }
    }
    
    /// Loads desktop names from the plist file
    private func loadDesktopNames() {
        guard let array = NSArray(contentsOfFile: plistPath) as? [String] else {
            // If plist doesn't exist, use default names
            print("ℹ️ No plist found, using defaults")
            text1 = "🏠 Home"
            text2 = "💻 Work"
            text3 = "🎮 Games"
            text4 = "📧 Email"
            text5 = "🎵 Music"
            text6 = "📱 Social"
            return
        }
        
        // Load names from plist
        text1 = array.count > 0 ? array[0] : ""
        text2 = array.count > 1 ? array[1] : ""
        text3 = array.count > 2 ? array[2] : ""
        text4 = array.count > 3 ? array[3] : ""
        text5 = array.count > 4 ? array[4] : ""
        text6 = array.count > 5 ? array[5] : ""
        
        print("✅ Loaded desktop names from plist: \(array)")
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
