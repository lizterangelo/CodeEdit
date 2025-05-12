//
//  AiderLoadingWindow.swift
//  CodeEdit
//
//  Created by CodeEdit on 10/26/2023.
//

import SwiftUI

/// Window for displaying Aider installation progress
struct AiderLoadingWindow: Scene {
    var body: some Scene {
        Window("Installing AI coding assistant tools", id: SceneID.aiderInstallation.rawValue) {
            AiderLoadingView()
                .onAppear {
                    print("AiderLoadingWindow Scene appeared")
                    
                    // Ensure this window is brought to front
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let window = NSApp.findWindow(.aiderInstallation) {
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                        }
                    }
                }
        }
        .defaultSize(width: 650, height: 450)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Disable new document command to prevent welcome window from opening
            CommandGroup(replacing: .newItem) {
                EmptyView()
            }
        }
    }
} 