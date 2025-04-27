//
//  AiderService.swift
//  CodeEdit
//
//  Created for CodeEdit App
//
//  Provides Aider integration with CodeEdit

import Foundation
import SwiftUI

/// Service for integrating Aider CLI assistant with CodeEdit
class AiderService: ObservableObject {
    private let shellClient = ShellClient()
    
    /// Shared instance of the service for use throughout the app
    static let shared = AiderService()
    
    /// Path to the app's Resources directory
    private var resourcesDirectory: String {
        Bundle.main.resourcePath ?? ""
    }
    
    /// Path to the bundled Aider wrapper script
    var aiderWrapperPath: String? {
        // Look for the script in the app bundle's Resources directory
        let path = Bundle.main.path(forResource: "aider_wrapper", ofType: "sh")
        print("Aider wrapper path: \(path ?? "not found")")
        return path
    }
    
    /// Check if Aider is properly bundled with the application
    var isAiderAvailable: Bool {
        aiderWrapperPath != nil
    }
    
    /// Installs Aider if it's not already installed
    /// - Returns: A command that ensures Aider is available
    func ensureAiderAvailable() -> String {
        // If Aider is already bundled, we're good
        if isAiderAvailable {
            return "echo 'Using bundled Aider'"
        }
        
        // Otherwise, check if Aider is installed with pip
        return """
        if ! command -v aider &> /dev/null; then
            echo "Installing Aider..."
            pip install aider-chat
        else
            echo "Using system Aider"
        fi
        """
    }
    
    /// Start Aider in a new terminal session
    /// - Parameter workspacePath: Path to the current workspace
    /// - Returns: Command to run in the terminal
    func startAider(workspacePath: String) -> String {
        // If we have the bundled wrapper, use it
        if let wrapperPath = aiderWrapperPath {
            let command = "cd \"\(workspacePath)\" && \"\(wrapperPath)\" -d ."
            print("Running Aider command: \(command)")
            return command
        }
        
        // Otherwise, try to install or use system Aider
        let command = """
        cd "\(workspacePath)" && {
            \(ensureAiderAvailable())
            if command -v aider &> /dev/null; then
                echo "Starting Aider..."
                aider -d .
            else
                echo "Failed to find or install Aider. Please make sure Python and pip are installed."
            fi
        }
        """
        print("Running Aider command: \(command)")
        return command
    }
    
    /// Start Aider with custom arguments
    /// - Parameters:
    ///   - workspacePath: Path to the current workspace
    ///   - arguments: Additional arguments to pass to Aider
    /// - Returns: Command to run in the terminal
    func startAider(workspacePath: String, arguments: [String]) -> String {
        let argsString = arguments.map { $0.replacingOccurrences(of: "\"", with: "\\\"") }.joined(separator: " ")
        
        // If we have the bundled wrapper, use it
        if let wrapperPath = aiderWrapperPath {
            let command = "cd \"\(workspacePath)\" && \"\(wrapperPath)\" \(argsString)"
            print("Running Aider command with arguments: \(command)")
            return command
        }
        
        // Otherwise, try to install or use system Aider
        let command = """
        cd "\(workspacePath)" && {
            \(ensureAiderAvailable())
            if command -v aider &> /dev/null; then
                echo "Starting Aider with options: \(argsString)"
                aider \(argsString)
            else
                echo "Failed to find or install Aider. Please make sure Python and pip are installed."
            fi
        }
        """
        print("Running Aider command with arguments: \(command)")
        return command
    }
} 