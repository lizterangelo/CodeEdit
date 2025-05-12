//
//  AiderInstallationManager.swift
//  CodeEdit
//
//  Created by CodeEdit on 10/26/2023.
//

import Foundation
import SwiftUI
import AppKit

/// Manager for Aider installation and checking
final class AiderInstallationManager: ObservableObject {
    static let shared = AiderInstallationManager()
    
    @Published var isInstalled: Bool = false
    @Published var isCheckingInstallation: Bool = false
    
    // Flag to track if installation window has been shown
    @Published var hasShownInstallationWindow: Bool = false
    
    private init() {
        checkIfAiderIsInstalled()
    }
    
    /// Checks if Aider is already installed
    func checkIfAiderIsInstalled() {
        print("Checking if Aider is installed...")
        isCheckingInstallation = true
        
        let process = Process()
        let outputPipe = Pipe()
        
        do {
            // Check if aider is in PATH
            try executeShellCommand(
                command: "which aider",
                outputPipe: outputPipe
            )
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let isAiderInstalled = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            // If we get a path, aider is installed
            DispatchQueue.main.async {
                self.isInstalled = isAiderInstalled
                self.isCheckingInstallation = false
                print("Aider installed: \(isAiderInstalled)")
                
                // If not installed and we haven't shown the window yet, show it
                if !isAiderInstalled && !self.hasShownInstallationWindow {
                    self.showInstallationWindow()
                }
            }
        } catch {
            print("Error checking Aider installation: \(error)")
            DispatchQueue.main.async {
                self.isInstalled = false
                self.isCheckingInstallation = false
            }
        }
    }
    
    /// Shows the Aider installation window
    func showInstallationWindow() {
        guard !isInstalled else {
            print("Aider is already installed, not showing window")
            return
        }
        
        // Close any welcome window that might have opened
        NSApp.closeWindow(.welcome)
        
        print("Posting notification to open Aider installation window")
        // Create a notification to open the window
        NotificationCenter.default.post(name: Notification.Name("OpenAiderInstallationWindow"), object: nil)
        
        // Mark that we've shown the window
        hasShownInstallationWindow = true
        
        // Ensure the window is brought to front after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let window = NSApp.findWindow(.aiderInstallation) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
    
    /// Execute a shell command
    private func executeShellCommand(command: String, outputPipe: Pipe) throws {
        let process = Process()
        process.environment = nil
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["--login", "-c", command]
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
    }
} 
