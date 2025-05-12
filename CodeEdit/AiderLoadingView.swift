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
    @State private var progress: Double = 0.0
    @State private var installationFailed: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Installing AI coding assistant tools")
                .font(.title)
                .fontWeight(.bold)
            
            Text("First-time installation may take a while. Please be patient.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 5)
            
            // Loading bar
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 8)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            
            if installationFailed {
                Text("Installation failed. AI chat will not work.")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Terminal output
            // Text("Installation Log")
            //     .font(.headline)
            //     .frame(maxWidth: .infinity, alignment: .leading)
            //     .padding(.horizontal)
            
            // ScrollView {
            //     Text(terminalOutput)
            //         .font(.system(.caption, design: .monospaced))
            //         .frame(maxWidth: .infinity, alignment: .leading)
            //         .padding()
            // }
            // .frame(width: 600, height: 150)
            // .background(Color(NSColor.textBackgroundColor))
//            .cornerRadius(8)
            
            Button("Close") {
                dismiss()
                
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
                        
                        // Secondary fallback to try to open welcome window directly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NSApp.sendAction(
                                Selector("openWindow:"), 
                                to: nil, 
                                from: SceneID.welcome.rawValue
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
        
        // Start progress animation
        startProgressAnimation()
        
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
                    if proc.terminationStatus == 0 {
                        self.runPostInstallCommands()
                    } else {
                        self.isInstalling = false
                        print("Aider installation failed with status: \(proc.terminationStatus)")
                        self.terminalOutput += "\n\n❌ Installation failed with status: \(proc.terminationStatus)"
                        self.installationFailed = true
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "\nError: \(error.localizedDescription)"
                self.isInstalling = false
                self.installationFailed = true
            }
        }
    }
    
    private func startProgressAnimation() {
        // Simulate progress with a timer
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !self.isInstalling {
                timer.invalidate()
                self.progress = 1.0
                return
            }
            
            // Gradually increase progress but slow down as it approaches 0.9
            // to give perception of progress while waiting for actual completion
            if self.progress < 0.9 {
                self.progress += (0.9 - self.progress) * 0.01
            }
        }
    }
    
    private func runPostInstallCommands() {
        self.terminalOutput += "\n\nRunning post-installation setup..."
        self.progress = 0.7 // Jump to 70% when starting post-install
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let pythonPath = "\(homeDir)/.local/share/uv/tools/aider-chat/bin/python3"
        
        // First command: ensure pip is installed
        let ensurepipProcess = Process()
        let ensurepipPipe = Pipe()
        
        do {
            ensurepipProcess.executableURL = URL(fileURLWithPath: pythonPath)
            ensurepipProcess.arguments = ["-m", "ensurepip", "--upgrade"]
            ensurepipProcess.standardOutput = ensurepipPipe
            ensurepipProcess.standardError = ensurepipPipe
            try ensurepipProcess.run()
            
            // Handle output
            let ensurepipHandle = ensurepipPipe.fileHandleForReading
            ensurepipHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let outputString = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.terminalOutput += outputString
                        }
                    }
                } else {
                    ensurepipHandle.readabilityHandler = nil
                }
            }
            
            // When ensurepip process completes, run pip install
            ensurepipProcess.terminationHandler = { proc in
                DispatchQueue.main.async {
                    if proc.terminationStatus == 0 {
                        self.terminalOutput += "\n\nInstalling aider-chat with browser support..."
                        self.installAiderWithBrowser(pythonPath: pythonPath)
                    } else {
                        self.terminalOutput += "\n\n❌ Ensurepip failed with status: \(proc.terminationStatus)"
                        self.isInstalling = false
                        self.installationFailed = true
                        
                        // Update AiderInstallationManager even if this step fails
                        AiderInstallationManager.shared.checkIfAiderIsInstalled()
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "\nError running ensurepip: \(error.localizedDescription)"
                self.isInstalling = false
                self.installationFailed = true
                
                // Update AiderInstallationManager even if this step fails
                AiderInstallationManager.shared.checkIfAiderIsInstalled()
            }
        }
    }
    
    private func installAiderWithBrowser(pythonPath: String) {
        self.progress = 0.85 // Jump to 85% when starting browser install
        let pipProcess = Process()
        let pipPipe = Pipe()
        
        do {
            pipProcess.executableURL = URL(fileURLWithPath: pythonPath)
            pipProcess.arguments = [
                "-m", "pip", "install", "--upgrade", 
                "--upgrade-strategy", "only-if-needed", 
                "aider-chat[browser]"
            ]
            pipProcess.standardOutput = pipPipe
            pipProcess.standardError = pipPipe
            try pipProcess.run()
            
            // Handle output
            let pipHandle = pipPipe.fileHandleForReading
            pipHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let outputString = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.terminalOutput += outputString
                        }
                    }
                } else {
                    pipHandle.readabilityHandler = nil
                }
            }
            
            // When pip install process completes
            pipProcess.terminationHandler = { proc in
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.progress = 1.0 // Set to 100% when complete
                    
                    if proc.terminationStatus == 0 {
                        print("Aider post-installation completed successfully")
                        
                        // Update AiderInstallationManager
                        AiderInstallationManager.shared.checkIfAiderIsInstalled()
                        
                        // Show installation complete message
                        self.terminalOutput += "\n\n✅ Installation complete!"
                        
                        // Automatically close after successful installation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.dismiss()
                            
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
                                    
                                    // Secondary fallback to try to open welcome window directly
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        NSApp.sendAction(
                                            Selector("openWindow:"), 
                                            to: nil, 
                                            from: SceneID.welcome.rawValue
                                        )
                                    }
                                }
                            }
                        }
                    } else {
                        print("Aider post-installation failed with status: \(proc.terminationStatus)")
                        self.terminalOutput += "\n\n❌ Installation failed with status: \(proc.terminationStatus)"
                        self.installationFailed = true
                        
                        // Update AiderInstallationManager even if this step fails
                        AiderInstallationManager.shared.checkIfAiderIsInstalled()
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "\nError installing aider-chat: \(error.localizedDescription)"
                self.isInstalling = false
                self.installationFailed = true
                
                // Update AiderInstallationManager even if this step fails
                AiderInstallationManager.shared.checkIfAiderIsInstalled()
            }
        }
    }
}

/// Window for displaying Aider installation progress
struct AiderLoadingWindow: Scene {
    var body: some Scene {
        Window("Installing AI coding assistant tools", id: "aider-installation") {
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
