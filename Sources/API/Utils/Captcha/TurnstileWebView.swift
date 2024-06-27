//
//  TurnstileWebView.swift
//  
//
//  Created by Mike Pitre on 6/14/24.
//

#if canImport(WebKit) && canImport(UIKit)

import SwiftUI
import WebKit

/// Use this view to acquire a Cloudflare Turnstile catpcha token.
///
/// If you have enabled bot protection via the Clerk dashboard, you will need a to provide a captcha token in order to sign up.
/// Use this view, and its `onSuccess` callback to acquire the necessary token.
///
/// - If you are using the invisible style widget type you can hide this view in the background since users will never need to interact with it.
/// - If you are using the smart style widget, you should place this view in your view heirarchy as users may need to intereact with the widget.
public struct TurnstileWebView: UIViewRepresentable {
    public init(
        appearence: Appearence = .always,
        size: Size = .regular,
        onDidFinishLoading: (() -> Void)? = nil,
        onBeforeInteractive: (() -> Void)? = nil,
        onSuccess: ((String) -> Void)? = nil,
        onError: ((String) -> Void)? = nil
    ) {
        self.appearence = appearence
        self.size = size
        self.onDidFinishLoading = onDidFinishLoading
        self.onBeforeInteractive = onBeforeInteractive
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    let appearence: Appearence
    let size: Size
    var onDidFinishLoading: (() -> Void)?
    var onBeforeInteractive: (() -> Void)?
    var onSuccess: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    public enum Size: String {
        case regular, compact
        
        var size: CGSize {
            switch self {
            case .regular:
                return CGSize(width: 300, height: 65)
            case .compact:
                return CGSize(width: 130, height: 120)
            }
        }
    }
    
    public enum Appearence {
        case always, execute, interactionOnly
        
        var stringValue: String {
            switch self {
            case .always:
                return "always"
            case .execute:
                return "execute"
            case .interactionOnly:
                return "interaction-only"
            }
        }
    }
    
    private let displayConfig = Clerk.shared.environment?.displayConfig
    
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

    public func makeUIView(context: Context) -> WKWebView {
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
            <div class="cf-turnstile" data-sitekey="\(siteKey)" data-callback="onSuccess" data-before-interactive-callback="onBeforeInteractive" data-error-callback="onError" data-appearance="\(appearence.stringValue)" data-size="\(size.rawValue)" data-retry-interval="500"></div>
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

    public func updateUIView(_ webView: WKWebView, context: Context) {
        // nothing
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            self,
            onDidFinishLoading: onDidFinishLoading,
            onSuccess: onSuccess,
            onBeforeInteractive: onBeforeInteractive,
            onError: onError
        )
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: TurnstileWebView
        var onDidFinishLoading: (() -> Void)?
        var onSuccess: ((String) -> Void)?
        var onBeforeInteractive: (() -> Void)?
        var onError: ((String) -> Void)?

        init(
            _ parent: TurnstileWebView,
            onDidFinishLoading: (() -> Void)?,
            onSuccess: ((String) -> Void)?,
            onBeforeInteractive: (() -> Void)?,
            onError: ((String) -> Void)?
        ) {
            self.parent = parent
            self.onDidFinishLoading = onDidFinishLoading
            self.onSuccess = onSuccess
            self.onBeforeInteractive = onBeforeInteractive
            self.onError = onError
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onDidFinishLoading?()
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
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
    
    public func onDidFinishLoading(perform onDidFinishLoading: @escaping () -> Void) -> Self {
        var copy = self
        copy.onDidFinishLoading = onDidFinishLoading
        return copy
    }
    
    /// A callback invoked upon success of the challenge. The callback is passed a token that can be validated.
    public func onSuccess(perform onSuccess: @escaping (_ token: String) -> Void) -> Self {
        var copy = self
        copy.onSuccess = onSuccess
        return copy
    }
    
    /// A callback invoked before the challenge enters interactive mode.
    public func onBeforeInteractive(perform onBeforeInteractive: @escaping () -> Void) -> Self {
        var copy = self
        copy.onBeforeInteractive = onBeforeInteractive
        return copy
    }
    
    /// A callback invoked when there is an error (e.g. network error or the challenge failed). Refer to Client-side errors.
    public func onError(perform onError: @escaping (_ errorMessage: String) -> Void) -> Self {
        var copy = self
        copy.onError = onError
        return copy
    }
    
}

#endif
