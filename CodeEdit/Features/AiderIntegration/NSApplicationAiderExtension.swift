//
//  NSApplicationAiderExtension.swift
//  CodeEdit
//
//  Created for CodeEdit App
//
//  Provides action handlers for Aider commands

import AppKit

extension NSApplication {
    /// Action handler for the Start Aider command
    @objc func startAiderAction(_ sender: Any?) {
        // Find the active window controller
        guard let windowController = keyWindow?.windowController as? CodeEditWindowController,
              let workspace = windowController.workspace,
              let workspacePath = workspace.fileURL?.path else {
            NSSound.beep()
            return
        }
        
        // Launch Aider in a terminal
        launchAiderInTerminal(workspacePath: workspacePath)
    }
    
    /// Action handler for the Start Aider with Options command
    @objc func startAiderWithOptionsAction(_ sender: Any?) {
        // Find the active window controller
        guard let windowController = keyWindow?.windowController as? CodeEditWindowController,
              let workspace = windowController.workspace,
              let workspacePath = workspace.fileURL?.path else {
            NSSound.beep()
            return
        }
        
        // Open dialog for options
        let alert = NSAlert()
        alert.messageText = "Aider Options"
        alert.informativeText = "Enter any additional command line arguments for Aider:"
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = inputTextField
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        
        activate(ignoringOtherApps: true)
        
        if alert.runModal() == .alertFirstButtonReturn {
            let options = inputTextField.stringValue
            launchAiderInTerminal(workspacePath: workspacePath, options: options)
        }
    }
    
    /// Helper method to launch Aider in a terminal
    private func launchAiderInTerminal(workspacePath: String, options: String = "") {
        // Find the active window controller
        guard let windowController = keyWindow?.windowController as? CodeEditWindowController,
              let workspace = windowController.workspace,
              let utilityAreaModel = workspace.utilityAreaModel else {
            NSSound.beep()
            return
        }
        
        // Create the workspace URL
        let workspaceURL = URL(fileURLWithPath: workspacePath)
        
        // Prepare Aider command with the provided options
        let command = options.isEmpty ? 
            AiderService.shared.startAider(workspacePath: workspacePath) :
            AiderService.shared.startAider(workspacePath: workspacePath, arguments: options.components(separatedBy: " "))
        
        // IMPORTANT: Defer UI updates to avoid "Publishing changes from within view updates" error
        // First ensure the utility area is visible
        DispatchQueue.main.async {
            // Make sure utility area is not collapsed
            if utilityAreaModel.isCollapsed {
                utilityAreaModel.isCollapsed = false
            }
            
            // Create and add a new terminal - doing this via a small delay to ensure UI has updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Add terminal
                utilityAreaModel.addTerminal(rootURL: workspaceURL)
                
                // Set terminal tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    utilityAreaModel.selectedTab = .terminal
                    
                    // Run Aider command in the terminal after everything is set up
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
            
            // Ensure utility drawer is visible
            self.sendAction(#selector(CodeEditWindowController.toggleLastPanel), to: nil, from: nil)
        }
    }
} 