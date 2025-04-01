import SwiftUI

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentMessage: String = ""
    @Published var isProcessing = false
    
    // Default welcome message
    init() {
        messages = [
            ChatMessage(
                content: "Hello! I'm the AI assistant. This is a placeholder implementation. In a real version, I would be connected to an AI service.",
                isUser: false
            )
        ]
    }
    
    func sendMessage() async {
        let trimmedMessage = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        let userMessage = ChatMessage(content: trimmedMessage, isUser: true)
        messages.append(userMessage)
        currentMessage = ""
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) 
        
        // Simple placeholder response
        let aiResponse = ChatMessage(
            content: "This is a placeholder response. In a real implementation, this would be connected to an AI service API that would generate relevant responses to your queries.",
            isUser: false
        )
        messages.append(aiResponse)
    }
    
    func clearChat() {
        messages = [
            ChatMessage(
                content: "Chat history cleared. This is a placeholder implementation.",
                isUser: false
            )
        ]
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
} 