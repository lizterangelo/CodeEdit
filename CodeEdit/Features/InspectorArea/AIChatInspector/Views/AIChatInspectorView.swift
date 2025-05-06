//
//  AIChatInspectorView.swift
//  CodeEdit
//
//  Created by AI Assistant
//

import SwiftUI
import WebKit

struct WebViewWrapper: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        nsView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error.localizedDescription)")
        }
    }
}

struct AIChatInspectorView: View {
    private let url = URL(string: "http://localhost:8501/")!
    
    var body: some View {
        WebViewWrapper(url: url)
    }
}

#Preview {
    AIChatInspectorView()
        .frame(width: 800, height: 600)
} 