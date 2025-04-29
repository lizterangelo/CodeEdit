//
//  TerminalChatView.swift
//  CodeEdit
//
//  Created by CodeEdit on 10/26/2023.
//

import SwiftUI

struct TerminalChatView: View {
    @State private var commandInput: String = ""
    @State private var terminalOutput: String = ""
    @State private var commandHistory: [String] = []
    @State private var currentHistoryIndex: Int = 0
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal output area
            ScrollView {
                Text(terminalOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // Command input area
            HStack {
                Text("$")
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
                
                TextField("Enter command...", text: $commandInput)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }
                    .onKeyDown { event in
                        switch event.keyCode {
                        case 126: // Up arrow
                            navigateHistory(up: true)
                            return true
                        case 125: // Down arrow
                            navigateHistory(up: false)
                            return true
                        default:
                            return false
                        }
                    }
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor))
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func executeCommand() {
        guard !commandInput.isEmpty else { return }
        
        // Add command to history
        commandHistory.append(commandInput)
        currentHistoryIndex = commandHistory.count
        
        // Add command to output
        terminalOutput += "\n$ \(commandInput)\n"
        
        // Execute command
        let process = Process()
        let outputPipe = Pipe()
        
        do {
            process.environment = nil
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["--login", "-c", commandInput]
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            try process.run()
            
            // Read output
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                terminalOutput += output
            }
            
            // Scroll to bottom
            DispatchQueue.main.async {
                withAnimation {
                    terminalOutput += "\n"
                }
            }
        } catch {
            terminalOutput += "Error: \(error.localizedDescription)\n"
        }
        
        // Clear input
        commandInput = ""
    }
    
    private func navigateHistory(up: Bool) {
        guard !commandHistory.isEmpty else { return }
        
        if up {
            if currentHistoryIndex > 0 {
                currentHistoryIndex -= 1
                commandInput = commandHistory[currentHistoryIndex]
            }
        } else {
            if currentHistoryIndex < commandHistory.count - 1 {
                currentHistoryIndex += 1
                commandInput = commandHistory[currentHistoryIndex]
            } else if currentHistoryIndex == commandHistory.count - 1 {
                currentHistoryIndex += 1
                commandInput = ""
            }
        }
    }
}

// Custom view modifier for handling keyboard events
struct KeyDownModifier: ViewModifier {
    let onKeyDown: (NSEvent) -> Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                KeyDownView(onKeyDown: onKeyDown)
            )
    }
}

// NSViewRepresentable to handle keyboard events
struct KeyDownView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyDownNSView()
        view.onKeyDown = onKeyDown
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Custom NSView to handle keyboard events
class KeyDownNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if let onKeyDown = onKeyDown, onKeyDown(event) {
            return
        }
        super.keyDown(with: event)
    }
}

// Extension to add the modifier to View
extension View {
    func onKeyDown(_ action: @escaping (NSEvent) -> Bool) -> some View {
        modifier(KeyDownModifier(onKeyDown: action))
    }
}

#Preview {
    TerminalChatView()
} 