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
                
                Button("Show Aider Documentation") {
                    if let url = URL(string: "https://aider.chat/docs/") {
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
