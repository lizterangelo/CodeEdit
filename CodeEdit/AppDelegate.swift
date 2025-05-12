//
//  AppDelegate.swift
//  CodeEdit
//
//  Created by Pavel Kasila on 12.03.22.
//

import SwiftUI
import CodeEditSymbols
import CodeEditSourceEditor
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "AppDelegate")
    private let updater = SoftwareUpdater()
    
    // Flag to track if we've already checked for Aider installation
    private var didCheckAiderInstallation = false

    @Environment(\.openWindow)
    var openWindow

    @LazyService var lspService: LSPService

    func applicationDidFinishLaunching(_ notification: Notification) {
        enableWindowSizeSaveOnQuit()
        Settings.shared.preferences.general.appAppearance.applyAppearance()
        
        // Close any welcome window that might have opened automatically
        NSApp.closeWindow(.welcome)
        
        // Setup notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openAiderInstallationWindow),
            name: Notification.Name("OpenAiderInstallationWindow"),
            object: nil
        )
        
        // Check if Aider is installed immediately
        checkAiderInstallation()
        
        // Start checking for files to open after Aider installation check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkForFilesToOpen()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showMainEditorWindow),
            name: Notification.Name("ShowMainEditorWindow"),
            object: nil
        )
    }
    
    // Check Aider installation and show installation window if needed
    private func checkAiderInstallation() {
        // Set flag to prevent multiple checks
        didCheckAiderInstallation = true
        
        if !AiderInstallationManager.shared.isInstalled {
            // Show installation window immediately
            DispatchQueue.main.async {
                self.openWindow(sceneID: .aiderInstallation)
            }
        } else {
            // If Aider is already installed, proceed with normal app flow
            DispatchQueue.main.async {
                self.handlePostAiderInstallation()
            }
        }
    }
    
    // Handle normal app flow after Aider installation check
    private func handlePostAiderInstallation() {
        var needToHandleOpen = true

        // If no windows were reopened by NSQuitAlwaysKeepsWindows, do default behavior.
        // Non-WindowGroup SwiftUI Windows are still in NSApp.windows when they are closed,
        // So we need to think about those.
        if NSApp.windows.count > NSApp.openSwiftUIWindows {
            needToHandleOpen = false
        }

        for index in 0..<CommandLine.arguments.count {
            if CommandLine.arguments[index] == "--open" && (index + 1) < CommandLine.arguments.count {
                let path = CommandLine.arguments[index+1]
                let url = URL(fileURLWithPath: path)

                CodeEditDocumentController.shared.reopenDocument(
                    for: url,
                    withContentsOf: url,
                    display: true
                ) { document, _, _ in
                    document?.windowControllers.first?.synchronizeWindowTitleWithDocumentName()
                }

                needToHandleOpen = false
            }
        }

        if needToHandleOpen {
            handleOpen()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Ensure all background AI services are stopped for each workspace
        let documents = CodeEditDocumentController.shared.documents.compactMap({ $0 as? WorkspaceDocument })
        for workspace in documents {
            workspace.aiService?.stop()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard flag else {
            // Only handle open if Aider is installed or we've already checked
            if AiderInstallationManager.shared.isInstalled || didCheckAiderInstallation {
                handleOpen()
            } else {
                checkAiderInstallation()
            }
            return false
        }

        /// Check if all windows are either miniaturized or not visible.
        /// If so, attempt to find the first miniaturized window and deminiaturize it.
        guard sender.windows.allSatisfy({ $0.isMiniaturized || !$0.isVisible }) else { return false }
        sender.windows.first(where: { $0.isMiniaturized })?.deminiaturize(sender)
        return false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func handleOpen() {
        let behavior = Settings.shared.preferences.general.reopenBehavior
        switch behavior {
        case .welcome:
            if !tryFocusWindow(id: .welcome) {
                openWindow(sceneID: .welcome)
            }
        case .openPanel:
            CodeEditDocumentController.shared.openDocument(self)
        case .newDocument:
            CodeEditDocumentController.shared.newDocument(self)
        }
    }

    /// Handle urls with the form `codeedit://file/{filepath}:{line}:{column}`
    func application(_ application: NSApplication, open urls: [URL]) {
        // First check if Aider is installed
        if !AiderInstallationManager.shared.isInstalled && !didCheckAiderInstallation {
            checkAiderInstallation()
            // Store URLs for later processing after installation
            self.pendingURLsToOpen = urls
            return
        }
        
        processURLs(urls)
    }
    
    // Property to store URLs that need to be opened after Aider installation
    private var pendingURLsToOpen: [URL]?
    
    // Process URLs to open
    private func processURLs(_ urls: [URL]) {
        for url in urls {
            let file = URL(fileURLWithPath: url.path).path.split(separator: ":")
            let filePath = URL(fileURLWithPath: String(file[0]))
            let line = file.count > 1 ? Int(file[1]) ?? 0 : 0
            let column = file.count > 2 ? Int(file[2]) ?? 1 : 1

            CodeEditDocumentController.shared
                .openDocument(withContentsOf: filePath, display: true) { document, _, error in
                    if let error {
                        NSAlert(error: error).runModal()
                        return
                    }
                    if line > 0, let document = document as? CodeFileDocument {
                        document.openOptions = CodeFileDocument.OpenOptions(
                            cursorPositions: [CursorPosition(line: line, column: column > 0 ? column : 1)]
                        )
                    }
                }
        }
    }

    /// Defers the application terminate message until we've finished cleanup.
    ///
    /// All paths _must_ call `NSApplication.shared.reply(toApplicationShouldTerminate: true)` as soon as possible.
    ///
    /// The two things needing deferring are:
    /// - Language server cancellation
    /// - Outstanding document changes.
    ///
    /// Things that don't need deferring (happen immediately):
    /// - Task termination.
    /// These are called immediately if no documents need closing, and are called by
    /// ``documentController(_:didCloseAll:contextInfo:)`` if there are documents we need to defer for.
    ///
    /// See ``terminateLanguageServers()`` and ``documentController(_:didCloseAll:contextInfo:)`` for deferring tasks.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let projects: [String] = CodeEditDocumentController.shared.documents
            .compactMap { ($0 as? WorkspaceDocument)?.fileURL?.path }

        UserDefaults.standard.set(projects, forKey: AppDelegate.recoverWorkspacesKey)

        let areAllDocumentsClean = CodeEditDocumentController.shared.documents.allSatisfy { !$0.isDocumentEdited }
        guard areAllDocumentsClean else {
            CodeEditDocumentController.shared.closeAllDocuments(
                withDelegate: self,
                didCloseAllSelector: #selector(documentController(_:didCloseAll:contextInfo:)),
                contextInfo: nil
            )
            // `documentController(_:didCloseAll:contextInfo:)` will call `terminateLanguageServers()`
            return .terminateLater
        }

        terminateTasks()
        terminateLanguageServers()
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Open windows

    @IBAction private func openWelcome(_ sender: Any) {
        // Check Aider installation first
        if !AiderInstallationManager.shared.isInstalled && !didCheckAiderInstallation {
            checkAiderInstallation()
        } else {
            openWindow(sceneID: .welcome)
        }
    }

    @IBAction private func openAbout(_ sender: Any) {
        // Check Aider installation first
        if !AiderInstallationManager.shared.isInstalled && !didCheckAiderInstallation {
            checkAiderInstallation()
        } else {
            openWindow(sceneID: .about)
        }
    }

    @IBAction func openFeedback(_ sender: Any) {
        // Check Aider installation first
        if !AiderInstallationManager.shared.isInstalled && !didCheckAiderInstallation {
            checkAiderInstallation()
            return
        }
        
        if tryFocusWindow(of: FeedbackView.self) { return }

        FeedbackView().showWindow()
    }

    @IBAction private func checkForUpdates(_ sender: Any) {
        updater.checkForUpdates()
    }

    @IBAction private func openAiderInstaller(_ sender: Any) {
        print("Manual trigger for Aider installation window")
        openWindow(sceneID: .aiderInstallation)
    }

    /// Tries to focus a window with specified view content type.
    /// - Parameter type: The type of viewContent which hosted in a window to be focused.
    /// - Returns: `true` if window exist and focused, otherwise - `false`
    private func tryFocusWindow<T: View>(of type: T.Type) -> Bool {
        guard let window = NSApp.windows.filter({ ($0.contentView as? NSHostingView<T>) != nil }).first
        else { return false }

        window.makeKeyAndOrderFront(self)
        return true
    }

    /// Tries to focus a window with specified sceneId
    /// - Parameter type: Id of a window to be focused.
    /// - Returns: `true` if window exist and focused, otherwise - `false`
    private func tryFocusWindow(id: SceneID) -> Bool {
        guard let window = NSApp.windows.filter({ $0.identifier?.rawValue == id.rawValue }).first
        else { return false }

        window.makeKeyAndOrderFront(self)
        return true
    }

    // MARK: - Open With CodeEdit (Extension) functions
    private func checkForFilesToOpen() {
        guard let defaults = UserDefaults.init(
            suiteName: "app.codeedit.CodeEdit.shared"
        ) else {
            print("Failed to get/init shared defaults")
            return
        }

        // Register enableOpenInCE (enable Open In CodeEdit
        defaults.register(defaults: ["enableOpenInCE": true])

        if let filesToOpen = defaults.string(forKey: "openInCEFiles") {
            let files = filesToOpen.split(separator: ";")
            
            // Check Aider installation first
            if !AiderInstallationManager.shared.isInstalled && !didCheckAiderInstallation {
                checkAiderInstallation()
                
                // Store file paths for later processing
                self.pendingFilesToOpen = files.map { String($0) }
                return
            }
            
            // Process files
            for filePath in files {
                let fileURL = URL(fileURLWithPath: String(filePath))
                CodeEditDocumentController.shared.reopenDocument(
                    for: fileURL,
                    withContentsOf: fileURL,
                    display: true
                ) { document, _, _ in
                    document?.windowControllers.first?.synchronizeWindowTitleWithDocumentName()
                }
            }

            defaults.removeObject(forKey: "openInCEFiles")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkForFilesToOpen()
        }
    }
    
    // Property to store file paths that need to be opened after Aider installation
    private var pendingFilesToOpen: [String]?

    /// Enable window size restoring on app relaunch after quitting.
    private func enableWindowSizeSaveOnQuit() {
        // This enables window restoring on normal quit (instead of only on force-quit).
        UserDefaults.standard.setValue(true, forKey: "NSQuitAlwaysKeepsWindows")
    }

    // MARK: NSDocumentController delegate

    @objc
    func documentController(_ docController: NSDocumentController, didCloseAll: Bool, contextInfo: Any) {
        if didCloseAll {
            terminateTasks()
            terminateLanguageServers()
        }
    }

    /// Terminates running language servers. Used during app termination to ensure resources are freed.
    private func terminateLanguageServers() {
        Task {
            await lspService.stopAllServers()
            await MainActor.run {
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            }
        }
    }

    /// Terminates all running tasks. Used during app termination to ensure resources are freed.
    private func terminateTasks() {
        let documents = CodeEditDocumentController.shared.documents.compactMap({ $0 as? WorkspaceDocument })
        documents.forEach { workspace in
            workspace.taskManager?.stopAllTasks()
            // Stop each workspace's AI service
            workspace.aiService?.stop()
        }
    }

    // Add a selector method to open the Aider installation window
    @objc private func openAiderInstallationWindow() {
        print("Opening Aider installation window")
        openWindow(sceneID: .aiderInstallation)
    }

    // Add a selector method to handle the fallback notification
    @objc private func showMainEditorWindow() {
        print("Received request to show main editor window")
        
        // Process any pending URLs or files after installation
        if let pendingURLs = pendingURLsToOpen {
            processURLs(pendingURLs)
            self.pendingURLsToOpen = nil
        }
        
        if let pendingFiles = pendingFilesToOpen {
            for filePath in pendingFiles {
                let fileURL = URL(fileURLWithPath: filePath)
                CodeEditDocumentController.shared.reopenDocument(
                    for: fileURL,
                    withContentsOf: fileURL,
                    display: true
                ) { document, _, _ in
                    document?.windowControllers.first?.synchronizeWindowTitleWithDocumentName()
                }
            }
            self.pendingFilesToOpen = nil
        }
        
        handleOpen()
    }
}

extension AppDelegate {
    static let recoverWorkspacesKey = "recover.workspaces"
}
