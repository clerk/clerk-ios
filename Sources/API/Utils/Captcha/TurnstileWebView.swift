//
//  TurnstileWebView.swift
//  
//
//  Created by Mike Pitre on 6/14/24.
//

#if canImport(WebKit)

import SwiftUI
import WebKit

struct TurnstileWebView: UIViewRepresentable {
    var onReceiveMessage: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "Turnstile")
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name='viewport' content='width=device-width,initial-scale=1,maximum-scale=1'/>
            <title>Cloudflare Turnstile</title>
            <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
            <style>
                body {
                    margin: 0;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                }
            </style>
            <script>
                function onSuccess(token) {
                    window.webkit.messageHandlers.Turnstile.postMessage(token);
                }
            </script>
        </head>
        <body>
            <div class="cf-turnstile" data-sitekey="" data-callback="onSuccess" data-appearance="interaction-only"></div>
        </body>
        </html>
        """

        if let homeURL = Clerk.shared.environment?.displayConfig.homeUrl {
            webView.loadHTMLString(html, baseURL: URL(string: homeURL))
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onReceiveMessage: onReceiveMessage)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: TurnstileWebView
        var onReceiveMessage: (String) -> Void

        init(_ parent: TurnstileWebView, onReceiveMessage: @escaping (String) -> Void) {
            self.parent = parent
            self.onReceiveMessage = onReceiveMessage
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView did finish loading")
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "Turnstile", let messageBody = message.body as? String {
                onReceiveMessage(messageBody)
            }
        }
    }
}

#endif
