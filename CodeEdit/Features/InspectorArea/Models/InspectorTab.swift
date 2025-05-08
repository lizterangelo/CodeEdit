//
//  InspectorTab.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 02/06/2023.
//

import SwiftUI
import CodeEditKit
import ExtensionFoundation

enum InspectorTab: WorkspacePanelTab {
    case file
    case gitHistory
    case internalDevelopment
<<<<<<< HEAD
    case terminalChat
=======
    case aiChat
>>>>>>> parent of 85cd3641 (Revert "ai chat")
    case uiExtension(endpoint: AppExtensionIdentity, data: ResolvedSidebar.SidebarStore)

    var systemImage: String {
        switch self {
        case .file:
            return "doc"
        case .gitHistory:
            return "clock"
        case .internalDevelopment:
            return "hammer"
<<<<<<< HEAD
        case .terminalChat:
            return "terminal"
=======
        case .aiChat:
            return "message"
>>>>>>> parent of 85cd3641 (Revert "ai chat")
        case .uiExtension(_, let data):
            return data.icon ?? "e.square"
        }
    }

    var id: String {
        if case .uiExtension(let endpoint, let data) = self {
            return endpoint.bundleIdentifier + data.sceneID
        }
        return title
    }

    var title: String {
        switch self {
        case .file:
            return "File Inspector"
        case .gitHistory:
            return "History Inspector"
        case .internalDevelopment:
            return "Internal Development"
<<<<<<< HEAD
        case .terminalChat:
            return "Terminal Chat"
=======
        case .aiChat:
            return "AI Chat"
>>>>>>> parent of 85cd3641 (Revert "ai chat")
        case .uiExtension(_, let data):
            return data.help ?? data.sceneID
        }
    }

    var body: some View {
        switch self {
        case .file:
            FileInspectorView()
        case .gitHistory:
            HistoryInspectorView()
        case .internalDevelopment:
            InternalDevelopmentInspectorView()
<<<<<<< HEAD
        case .terminalChat:
            TerminalChatView()
=======
        case .aiChat:
            AIChatInspectorView()
>>>>>>> parent of 85cd3641 (Revert "ai chat")
        case let .uiExtension(endpoint, data):
            ExtensionSceneView(with: endpoint, sceneID: data.sceneID)
        }
    }
}
