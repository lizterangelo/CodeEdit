import SwiftUI
import Foundation
import WebKit

/// AIChatInspectorView that embeds the Aider web interface
struct AIChatInspectorView: View {
    @EnvironmentObject var workspace: WorkspaceDocument
    @State private var webViewURL: URL?
    
    var body: some View {
        ZStack {
            if let url = webViewURL {
                // Web view with Aider interface
                WebViewWrapper(url: url)
            } else {
                // Loading view
                VStack(spacing: 20) {
                    Text("AI Assistant")
                        .font(.headline)
                    
                    if let aiService = workspace.aiService, aiService.isRunning {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading Aider web interface...")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Waiting for AI service to start...")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // Check if URL is already available from workspace's AI service
            if let aiService = workspace.aiService, let url = aiService.localhostURL {
                self.webViewURL = url
            }
            
            // Listen for URL availability notification with workspace ID filtering
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AiderWebInterfaceURLAvailable"),
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let url = userInfo["url"] as? URL,
                   let workspaceID = userInfo["workspaceID"] as? UUID,
                   workspaceID == workspace.id {
                    self.webViewURL = url
                }
            }
        }
    }
}

/// WebView wrapper for SwiftUI
struct WebViewWrapper: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Optional: Inject custom CSS or JavaScript here if needed
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let mockWorkspace = WorkspaceDocument()
    return AIChatInspectorView()
        .frame(width: 800, height: 600)
        .environmentObject(mockWorkspace)
}