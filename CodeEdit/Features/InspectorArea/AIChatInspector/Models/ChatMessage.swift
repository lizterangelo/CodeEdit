//
//  ChatMessage.swift
//  CodeEdit
//
//  Created by AI Assistant
//

import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: Date = Date()
} 