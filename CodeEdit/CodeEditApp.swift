//
//  CodeEditApp.swift
//  CodeEdit
//
//  Created by Wouter Hennen on 11/03/2023.
//

import SwiftUI

@main
struct CodeEditApp: App {
    @NSApplicationDelegateAdaptor var appdelegate: AppDelegate
    @ObservedObject var settings = Settings.shared
    
    // Flag to track if we need to show Aider installation window
    @State private var needsAiderCheck: Bool = true

    let updater: SoftwareUpdater = SoftwareUpdater()

    init() {
        // Register singleton services before anything else
        ServiceContainer.register(
            LSPService()
        )

        _ = CodeEditDocumentController.shared
        NSMenuItem.swizzle()
        NSSplitViewItem.swizzle()
    }

    var body: some Scene {
        Group {
            // Only show AiderLoadingWindow first
            AiderLoadingWindow()
                .handlesExternalEvents(matching: Set(arrayLiteral: "aider-installation"))
            
            // Other windows are conditionally shown
            WelcomeWindow()
                .handlesExternalEvents(matching: Set(arrayLiteral: "welcome"))
                .commands {
                    // This ensures welcome window doesn't automatically open on launch
                    CommandGroup(replacing: .newItem) {
                        EmptyView()
                    }
                }

            ExtensionManagerWindow()

            AboutWindow()

            SettingsWindow()
                .commands {
                    CodeEditCommands()
                }
        }
        .environment(\.settings, settings.preferences) // Add settings to each window environment
    }
}
