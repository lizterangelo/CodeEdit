import Foundation
import SwiftUI

/// A service that runs Aider in the background without UI
final class BackgroundAIService: ObservableObject {
    static let shared = BackgroundAIService()
    
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var localhostURL: URL?
    
    private var process: Process?
    private var apiKey: String = ""
    private var workspacePath: String?
    private var terminalOutput: String = ""
    
    private init() {
        // Initialize but don't start the service until a workspace is opened
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(workspaceDidOpen(_:)),
            name: NSNotification.Name("WorkspaceDidOpen"),
            object: nil
        )
        
        // Also listen for application termination to clean up
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Start the background AI service for a specific workspace
    func start(for workspaceURL: URL) {
        guard !isRunning, let workspacePath = workspaceURL.path as String? else {
            return
        }
        
        self.workspacePath = workspacePath
        self.localhostURL = nil
        
        // Fetch API key and start the service
        fetchApiKey { [weak self] key in
            guard let self = self, !key.isEmpty else { return }
            
            self.apiKey = key
            self.copyQAInstructionsToWorkspace { success in
                if success {
                    self.runAiderCommand()
                } else {
                    print("Failed to copy QA instructions file. Aborting background AI service.")
                }
            }
        }
    }
    
    /// Stop the background AI service
    func stop() {
        guard isRunning, let process = process else { return }
        
        process.terminate()
        isRunning = false
        self.process = nil
        self.localhostURL = nil
        print("Background AI service stopped")
    }
    
    /// Fetch the API key from the cloud function
    private func fetchApiKey(completion: @escaping (String) -> Void) {
        // URL to your Google Cloud Function
        guard let url = URL(string: "https://pythoninstallation-369680016890.us-central1.run.app") else {
            print("Error: Invalid API URL")
            completion("")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching API key: \(error.localizedDescription)")
                completion("")
                return
            }
            
            guard let data = data,
                  let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let apiKey = jsonResponse["pythonCode"] as? String else {
                print("Error: Invalid response format")
                completion("")
                return
            }
            
            print("API key fetched successfully")
            completion(apiKey)
        }
        
        print("Fetching API key...")
        task.resume()
    }
    
    /// Copy QA instructions to the workspace
    private func copyQAInstructionsToWorkspace(completion: @escaping (Bool) -> Void) {
        guard let workspacePath = workspacePath else {
            completion(false)
            return
        }
        
        // Get the path to the QA_INSTRUCTION_CONTENT.md file in the app bundle
        guard let bundlePath = Bundle.main.path(forResource: "QA_INSTRUCTION_CONTENT", ofType: "md") else {
            print("Error: Could not find QA_INSTRUCTION_CONTENT.md in app bundle")
            completion(false)
            return
        }
        
        // Destination path in the workspace
        let destinationPath = "\(workspacePath)/QA_INSTRUCTIONS.md"
        
        do {
            // Read the content from the bundle file
            let content = try String(contentsOfFile: bundlePath, encoding: .utf8)
            
            // Write the content to the destination file
            try content.write(toFile: destinationPath, atomically: true, encoding: .utf8)
            
            print("Successfully copied QA_INSTRUCTIONS.md to workspace")
            completion(true)
        } catch {
            print("Error copying QA instructions file: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    /// Run the Aider command in the background
    private func runAiderCommand() {
        guard !isRunning, let workspacePath = workspacePath else { return }
        
        // Get the home directory path dynamically for the current user
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let aiderPath = "\(homeDirectory)/.local/bin/aider"
        
        print("Starting background AI service with Aider...")
        
        // Create and configure the process
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        // Set the GEMINI_API_KEY environment variable before running the command
        // Note: We're now using --browser flag to open the web interface
        process.arguments = ["bash", "-c", "export GEMINI_API_KEY=\(apiKey) && cd \(workspacePath) && \(aiderPath) --model gemini/gemini-2.5-flash-preview-04-17 --read QA_INSTRUCTIONS.md --browser"]
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Set up a handler for the process output
        pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.terminalOutput += output
                    // Check for localhost URL in the output
                    self?.extractLocalhostURL(from: output)
                }
            }
        }
        
        // Set up completion handler
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.isRunning = false
                print("Background AI service terminated with exit code \(process.terminationStatus)")
                
                // Close the file handle
                pipe.fileHandleForReading.readabilityHandler = nil
                self?.process = nil
                self?.localhostURL = nil
            }
        }
        
        // Start the process
        do {
            try process.run()
            self.process = process
            self.isRunning = true
            print("Background AI service started successfully")
        } catch {
            print("Error starting background AI service: \(error.localizedDescription)")
            self.isRunning = false
        }
    }
    
    /// Extract localhost URL from Aider output
    private func extractLocalhostURL(from output: String) {
        // Common pattern for localhost URLs in Aider output
        let patterns = [
            "http://localhost:\\d+",
            "http://127.0.0.1:\\d+"
        ]
        
        for pattern in patterns {
            if let range = output.range(of: pattern, options: .regularExpression) {
                let urlString = String(output[range])
                if let url = URL(string: urlString) {
                    self.localhostURL = url
                    print("Found Aider web interface URL: \(urlString)")
                    
                    // Post notification that the URL is available
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AiderWebInterfaceURLAvailable"),
                        object: url
                    )
                    return
                }
            }
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func workspaceDidOpen(_ notification: Notification) {
        // Extract workspace URL from notification
        if let workspace = notification.object as? WorkspaceDocument, let fileURL = workspace.fileURL {
            // Stop any existing service first
            if isRunning {
                stop()
            }
            
            // Start the service for the new workspace
            start(for: fileURL)
        }
    }
    
    @objc private func applicationWillTerminate(_ notification: Notification) {
        // Clean up when the application is about to terminate
        stop()
    }
} 