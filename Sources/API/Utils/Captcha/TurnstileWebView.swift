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
    var onFinishLoading: (() -> Void)?
    var onSuccess: ((String) -> Void)?
    var onBeforeInteractive: (() -> Void)?
    var onError: ((String) -> Void)?
    
    let displayConfig = Clerk.shared.environment?.displayConfig
    
    private var siteKey: String {
        switch displayConfig?.captchaWidgetType {
        case .invisible:
            return displayConfig?.captchaPublicKeyInvisible ?? ""
        case .smart:
            return displayConfig?.captchaPublicKey ?? ""
        case nil:
            return ""
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "onSuccess")
        contentController.add(context.coordinator, name: "onBeforeInteractive")
        contentController.add(context.coordinator, name: "onError")
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name='viewport' content='width=device-width, initial-scale=1, maximum-scale=1'/>
            <title>Cloudflare Turnstile</title>
            <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
            <style>
                body {
                    margin: 0;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 108vh;
                }
            </style>
            <script>
                function onSuccess(token) {
                    window.webkit.messageHandlers.onSuccess.postMessage(token);
                }
                function onBeforeInteractive() {
                    window.webkit.messageHandlers.onBeforeInteractive.postMessage(null);
                }
                function onError(errorMessage) {
                    window.webkit.messageHandlers.onError.postMessage(errorMessage);
                }
            </script>
        </head>
        <body>
            <div class="cf-turnstile" data-sitekey="\(siteKey)" data-callback="onSuccess" data-before-interactive-callback="onBeforeInteractive" data-error-callback="onError" data-appearance="interaction-only"></div>
        </body>
        </html>
        """

        if let homeURL = Clerk.shared.environment?.displayConfig.homeUrl {
            webView.loadHTMLString(html, baseURL: URL(string: homeURL))
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }
        
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // nothing
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            self,
            onFinishLoading: onFinishLoading,
            onSuccess: onSuccess,
            onBeforeInteractive: onBeforeInteractive,
            onError: onError
        )
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: TurnstileWebView
        var onFinishLoading: (() -> Void)?
        var onSuccess: ((String) -> Void)?
        var onBeforeInteractive: (() -> Void)?
        var onError: ((String) -> Void)?

        init(
            _ parent: TurnstileWebView,
            onFinishLoading: (() -> Void)?,
            onSuccess: ((String) -> Void)?,
            onBeforeInteractive: (() -> Void)?,
            onError: ((String) -> Void)?
        ) {
            self.parent = parent
            self.onFinishLoading = onFinishLoading
            self.onSuccess = onSuccess
            self.onBeforeInteractive = onBeforeInteractive
            self.onError = onError
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onFinishLoading?()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "onSuccess":
                if let messageBody = message.body as? String {
                    onSuccess?(messageBody)
                }
            case "onBeforeInteractive":
                onBeforeInteractive?()
            case "onError":
                if let messageBody = message.body as? String {
                    onError?(messageBody)
                }
            default:
                break
            }
        }
    }
}

extension TurnstileWebView {
    
    func onFinishLoading(perform onFinishLoading: @escaping () -> Void) -> Self {
        var copy = self
        copy.onFinishLoading = onFinishLoading
        return copy
    }
    
    func onSuccess(perform onSuccess: @escaping (_ token: String) -> Void) -> Self {
        var copy = self
        copy.onSuccess = onSuccess
        return copy
    }
    
    func onBeforeInteractive(perform onBeforeInteractive: @escaping () -> Void) -> Self {
        var copy = self
        copy.onBeforeInteractive = onBeforeInteractive
        return copy
    }
    
    func onError(perform onError: @escaping (_ errorMessage: String) -> Void) -> Self {
        var copy = self
        copy.onError = onError
        return copy
    }
    
}

#endif
