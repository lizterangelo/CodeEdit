import SwiftUI

struct AIChatInspectorView: View {
    @StateObject private var viewModel = AIChatViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Form {
            Section("AI Chat") {
                chatView
            }
            
            Section {
                Button("Clear Chat") {
                    viewModel.clearChat()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
    }
    
    private var chatView: some View {
        VStack(spacing: 8) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if viewModel.messages.isEmpty {
                            HStack {
                                Spacer()
                                Text("No messages")
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 20)
                                Spacer()
                            }
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                .cornerRadius(6)
                .frame(height: 300)
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // Input area
            HStack(spacing: 8) {
                TextField("Ask anything...", text: $viewModel.currentMessage)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isProcessing)
                    .onSubmit {
                        if !viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                            && !viewModel.isProcessing {
                            Task {
                                await viewModel.sendMessage()
                            }
                        }
                    }
                
                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(8)
                    .background(message.isUser ? 
                                Color.blue.opacity(0.2) : 
                                (colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.9)))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
} 