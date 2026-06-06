//
//  SafariView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI
import WebKit

#if os(iOS)
import SafariServices

struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context _: Context) -> SFSafariViewController {
    SFSafariViewController(url: url)
  }

  func updateUIViewController(_: SFSafariViewController, context _: Context) {
    // No updates needed as URL doesn't change after creation
  }
}

#elseif os(macOS)

struct SafariView: NSViewRepresentable {
  let url: URL

  func makeNSView(context _: Context) -> WKWebView {
    let webView = WKWebView()
    webView.load(URLRequest(url: url))
    return webView
  }

  func updateNSView(_ webView: WKWebView, context _: Context) {
    guard webView.url != url else { return }
    webView.load(URLRequest(url: url))
  }
}

#endif

struct SafariSheetItem: Identifiable {
  let id = UUID()
  let url: URL
}

#endif
