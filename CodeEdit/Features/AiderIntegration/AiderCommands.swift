//
//  AiderCommands.swift
//  CodeEdit
//
//  Created for CodeEdit App
//
//  Provides Aider commands menu for CodeEdit

import SwiftUI

/// Command menu for Aider AI assistant integration
struct AiderCommands: Commands {
    @FocusedObject private var workspaceDocument: WorkspaceDocument?
    @UpdatingWindowController private var windowController: CodeEditWindowController?
    
    @FocusedObject private var utilityAreaViewModel: UtilityAreaViewModel?
    
    // Check if there's an active workspace through the window controller
    private var hasActiveWorkspace: Bool {
        windowController?.workspace != nil
    }
    
    var body: some Commands {
        CommandMenu("Aider") {
            // Standard Aider commands
            Group {
                Button("Start Aider") {
                    startAider()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(!hasActiveWorkspace)
                
                Button("Start Aider with Options...") {
                    startAiderWithOptions()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift, .option])
                .disabled(!hasActiveWorkspace)
                
                Divider()
                
                // Add model selection submenu
                Menu("Start with Model") {
                    Button("OpenAI - GPT-4o") {
                        startAiderWithModel("o4")
                    }
                    Button("OpenAI - GPT-4o mini") {
                        startAiderWithModel("o4-mini")
                    }
                    Button("OpenAI - GPT-3.5") {
                        startAiderWithModel("gpt-3.5-turbo")
                    }
                    Divider()
                    Button("Claude 3 Opus") {
                        startAiderWithModel("opus")
                    }
                    Button("Claude 3 Sonnet") {
                        startAiderWithModel("sonnet")
                    }
                    Button("Claude 3 Haiku") {
                        startAiderWithModel("haiku")
                    }
                    Divider()
                    Button("DeepSeek Coder") {
                        startAiderWithModel("deepseek")
                    }
                }
                .disabled(!hasActiveWorkspace)
                
                // Add API key configuration
                Menu("Configure API Keys") {
                    Button("Set OpenAI API Key...") {
                        configureAPIKey("openai")
                    }
                    Button("Set Anthropic API Key...") {
                        configureAPIKey("anthropic")
                    }
                    Button("Set DeepSeek API Key...") {
                        configureAPIKey("deepseek")
                    }
                    Button("Set Custom API Key...") {
                        configureAPIKey("custom")
                    }
                }
            }
            
            Divider()
            
            Group {
                Button("Show Aider Documentation") {
                    if let url = URL(string: "https://aider.chat/docs/") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Visit Aider Website") {
                    if let url = URL(string: "https://aider.chat") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    /// Start Aider in a terminal with default options
    private func startAider() {
        // First try to get the workspace from the controller
        guard let workspace = windowController?.workspace,
              let workspacePath = workspace.fileURL?.path else {
            NSSound.beep()
            return
        }
        
        // Create a new terminal
        createTerminalWithAider(workspacePath: workspacePath)
    }
    
    /// Start Aider with custom options
    private func startAiderWithOptions() {
        // First try to get the workspace from the controller
        guard let workspace = windowController?.workspace,
              let workspacePath = workspace.fileURL?.path else {
            NSSound.beep()
            return
        }
        
        // Open a dialog to get options
        let alert = NSAlert()
        alert.messageText = "Aider Options"
        alert.informativeText = "Enter any additional command line arguments for Aider:"
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = inputTextField
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        
        NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            let options = inputTextField.stringValue
            createTerminalWithAider(workspacePath: workspacePath, options: options)
        }
    }
    
    /// Start Aider with a specific model
    /// - Parameter model: The model name to use with Aider
    private func startAiderWithModel(_ model: String) {
        // First try to get the workspace from the controller
        guard let workspace = windowController?.workspace,
              let workspacePath = workspace.fileURL?.path else {
            NSSound.beep()
            return
        }
        
        // Launch Aider with the specified model
        createTerminalWithAider(workspacePath: workspacePath, options: "--model \(model)")
    }
    
    /// Configure an API key for the specified service
    /// - Parameter service: The service to configure the API key for (openai, anthropic, etc.)
    private func configureAPIKey(_ service: String) {
        // Create an alert to get the API key
        let alert = NSAlert()
        alert.messageText = "Configure \(service.capitalized) API Key"
        alert.informativeText = "Enter your \(service.capitalized) API key:"
        
        let inputTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        // Set a default test API key
        inputTextField.stringValue = "sk_test_12345678" // Default test key
        
        alert.accessoryView = inputTextField
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            let apiKey = inputTextField.stringValue
            // Simply check if empty instead of using guard with optional binding
            if apiKey.isEmpty {
                return
            }
            
            // Create a directory for Aider configuration if it doesn't exist
            let fileManager = FileManager.default
            let configDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".aider")
            
            do {
                // Create the directory if it doesn't exist
                if !fileManager.fileExists(atPath: configDir.path) {
                    try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
                }
                
                // Create or update the .env file in the .aider directory
                var envFilePath = configDir.appendingPathComponent(".env")
                
                // Read existing .env file if it exists
                var envContent = ""
                if fileManager.fileExists(atPath: envFilePath.path) {
                    envContent = try String(contentsOf: envFilePath, encoding: .utf8)
                }
                
                // Determine the environment variable name
                let envVarName: String
                if service == "custom" {
                    // For custom API key, ask for the variable name
                    let customAlert = NSAlert()
                    customAlert.messageText = "Custom API Key"
                    customAlert.informativeText = "Enter the environment variable name for this API key:"
                    
                    let customTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                    // Set a default variable name
                    customTextField.stringValue = "CUSTOM_API_KEY"
                    
                    customAlert.accessoryView = customTextField
                    customAlert.addButton(withTitle: "Save")
                    customAlert.addButton(withTitle: "Cancel")
                    
                    if customAlert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
                        let varName = customTextField.stringValue
                        // Check if empty without using guard with optional binding
                        if varName.isEmpty {
                            return
                        }
                        envVarName = varName
                    } else {
                        return
                    }
                } else {
                    // Standard API key variable names
                    switch service {
                    case "openai":
                        envVarName = "OPENAI_API_KEY"
                    case "anthropic":
                        envVarName = "ANTHROPIC_API_KEY"
                    case "deepseek":
                        envVarName = "DEEPSEEK_API_KEY"
                    default:
                        envVarName = "\(service.uppercased())_API_KEY"
                    }
                }
                
                // Update or add the API key to the .env file
                let lines = envContent.components(separatedBy: .newlines)
                var updated = false
                var newLines: [String] = []
                
                for line in lines {
                    if line.hasPrefix("\(envVarName)=") {
                        newLines.append("\(envVarName)=\"\(apiKey)\"")
                        updated = true
                    } else if !line.isEmpty {
                        newLines.append(line)
                    }
                }
                
                if !updated {
                    newLines.append("\(envVarName)=\"\(apiKey)\"")
                }
                
                // Write the updated .env file
                try newLines.joined(separator: "\n").write(to: envFilePath, atomically: true, encoding: .utf8)
                
                // Show success message
                let successAlert = NSAlert()
                successAlert.messageText = "API Key Saved"
                successAlert.informativeText = "The \(service) API key has been saved successfully."
                successAlert.runModal()
                
            } catch {
                // Show error message
                let errorAlert = NSAlert()
                errorAlert.messageText = "Error Saving API Key"
                errorAlert.informativeText = "Could not save the API key: \(error.localizedDescription)"
                errorAlert.runModal()
            }
        }
    }
    
    /// Create a new terminal and run Aider in it
    /// - Parameters:
    ///   - workspacePath: Path to the current workspace
    ///   - options: Optional command line arguments
    private func createTerminalWithAider(workspacePath: String, options: String = "") {
        guard let workspace = windowController?.workspace,
              let utilityAreaModel = workspace.utilityAreaModel else {
            NSSound.beep()
            return
        }
        
        // Create workspace URL
        let workspaceURL = URL(fileURLWithPath: workspacePath)
        
        // Prepare the command
        let command = options.isEmpty ? 
            AiderService.shared.startAider(workspacePath: workspacePath) :
            AiderService.shared.startAider(workspacePath: workspacePath, arguments: options.components(separatedBy: " "))
        
        // IMPORTANT: Defer UI updates to avoid "Publishing changes from within view updates" error
        DispatchQueue.main.async {
            // Open utility area if needed
            NSApp.sendAction(#selector(CodeEditWindowController.toggleLastPanel), to: nil, from: nil)
            
            // Make sure utility area is not collapsed
            if utilityAreaModel.isCollapsed {
                utilityAreaModel.isCollapsed = false
            }
            
            // Add terminal with small delay to ensure UI has updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                utilityAreaModel.addTerminal(rootURL: workspaceURL)
                
                // Set terminal tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    utilityAreaModel.selectedTab = .terminal
                    
                    // Run Aider command after everything is set up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let shellClient = ShellClient()
                        do {
                            try shellClient.run(command)
                        } catch {
                            print("Failed to start Aider: \(error)")
                        }
                    }
                }
            }
        }
    }
} 
