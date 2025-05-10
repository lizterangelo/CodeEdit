import SwiftUI
import Foundation

struct AIChatInspectorView: View {
    @EnvironmentObject var workspace: WorkspaceDocument
    @State private var terminalOutput: String = "Initializing aider..."
    @State private var isRunning: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Aider Terminal")
                .font(.headline)
                .padding([.top, .horizontal])
            
            ZStack(alignment: .topLeading) {
                // Terminal background
                Rectangle()
                    .fill(Color.black)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 10) {
                    // Terminal output
                    ScrollView {
                        Text(terminalOutput)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Status indicator
                    if isRunning {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            Text("Aider running...")
                                .foregroundColor(.gray)
                                .padding(.leading, 5)
                        }
                        .padding(10)
                    }
                }
            }
            .padding([.horizontal, .bottom])
        }
        .onAppear {
            runAiderCommand()
        }
    }
    
    private func runAiderCommand() {
        isRunning = true
        
        // Get the home directory path dynamically for the current user
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let aiderPath = "\(homeDirectory)/.local/bin/aider"
        
        // Get the workspace directory path from the workspace's fileURL
        guard let workspacePath = workspace.fileURL?.path else {
            terminalOutput = "Error: Could not get workspace path"
            isRunning = false
            return
        }
        
        terminalOutput = "$ cd \(workspacePath) && \(aiderPath) --browser\n"
        
        // Create and configure the process
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", "-c", "cd \(workspacePath) && \(aiderPath) --browser"]
        process.standardOutput = pipe
        process.standardError = pipe
        
        // Set up a handler for the process output
        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.terminalOutput += output
                }
            }
        }
        
        // Set up completion handler
        process.terminationHandler = { process in
            DispatchQueue.main.async {
                self.isRunning = false
                self.terminalOutput += "\nProcess completed with exit code \(process.terminationStatus)\n"
                
                // Close the file handle
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        }
        
        // Start the process
        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                self.terminalOutput += "Error: \(error.localizedDescription)\n"
                self.isRunning = false
            }
        }
    }
}

#Preview {
    let mockWorkspace = WorkspaceDocument()
    return AIChatInspectorView()
        .frame(width: 800, height: 600)
        .environmentObject(mockWorkspace)
}