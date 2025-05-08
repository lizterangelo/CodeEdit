//
//  ChatBubbleView.swift
//  CodeEdit
//
//  Created by AI Assistant
//

import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(message.isUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                )
                .foregroundColor(.primary)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

#Preview {
    Group {
        ChatBubbleView(message: ChatMessage(id: "1", content: "Hello, how can I help with your code?", isUser: false))
        ChatBubbleView(message: ChatMessage(id: "2", content: "I'm trying to implement a new feature", isUser: true))
    }
    .padding()
} 