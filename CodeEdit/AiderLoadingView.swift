//
//  AiderLoadingView.swift
//  CodeEdit
//
//  Created by CodeEdit on 10/26/2023.
//

import SwiftUI

/// View that shows Aider installation progress
struct AiderLoadingView: View {
    @State private var terminalOutput: String = ""
    @State private var isInstalling: Bool = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Installing Aider")
                .font(.title)
                .fontWeight(.bold)
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            ScrollView {
                Text(terminalOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(width: 600, height: 300)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            
            Button("Close") {
                dismiss()
                
                // Only show main editor window if Aider is installed
                if !isInstalling && AiderInstallationManager.shared.isInstalled {
                    // Delay needed to ensure the window closing completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Show default window based on user preferences
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.handleOpen()
                        } else {
                            // Fallback approach to ensure some window is shown
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ShowMainEditorWindow"),
                                object: nil
                            )
                        }
                    }
                }
            }
            .disabled(isInstalling)
        }
        .frame(width: 650, height: 450)
        .padding()
        .onAppear {
            print("AiderLoadingView appeared")
            installAider()
        }
    }
    
    private func installAider() {
        print("Starting Aider installation...")
        let process = Process()
        let outputPipe = Pipe()
        
        do {
            // Execute aider installation command
            process.environment = nil
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["--login", "-c", "curl -LsSf https://aider.chat/install.sh | sh"]
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            try process.run()
            
            // Create a file handle to read the output
            let fileHandle = outputPipe.fileHandleForReading
            
            // Set up async reading of the pipe
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let outputString = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.terminalOutput += outputString
                        }
                    }
                } else {
                    // End of file
                    fileHandle.readabilityHandler = nil
                }
            }
            
            // When the process exits
            process.terminationHandler = { proc in
                DispatchQueue.main.async {
                    self.isInstalling = false
                    print("Aider installation completed with status: \(proc.terminationStatus)")
                    
                    // Update AiderInstallationManager
                    AiderInstallationManager.shared.checkIfAiderIsInstalled()
                    
                    if proc.terminationStatus == 0 {
                        // Installation successful
                        self.terminalOutput += "\n\n✅ Installation complete! You can now close this window."
                        
                        // Auto-close the window after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self.dismiss()
                            
                            // Show main window after installation is complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let appDelegate = NSApp.delegate as? AppDelegate {
                                    appDelegate.handleOpen()
                                } else {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("ShowMainEditorWindow"),
                                        object: nil
                                    )
                                }
                            }
                        }
                    } else {
                        // Installation failed
                        self.terminalOutput += "\n\n❌ Installation failed with error code: \(proc.terminationStatus)"
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "\nError: \(error.localizedDescription)"
                self.isInstalling = false
            }
        }
    }
}

/// Window for displaying Aider installation progress
struct AiderLoadingWindow: Scene {
    var body: some Scene {
        Window("Installing Aider", id: "aider-installation") {
            AiderLoadingView()
                .onAppear {
                    print("AiderLoadingWindow Scene appeared")
                }
        }
        .defaultSize(width: 650, height: 450)
        .windowResizability(.contentSize)
    }
}

#Preview {
    AiderLoadingView()
} 
