//
//  PresentationAnchorProvider.swift
//

#if canImport(AuthenticationServices) && !os(watchOS) && (canImport(UIKit) || canImport(AppKit))

import AuthenticationServices

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PresentationAnchorProvider {
  @MainActor
  static var current: ASPresentationAnchor {
    #if canImport(UIKit) && !os(macOS)
    let foregroundWindows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap(\.windows)

    return foregroundWindows.first(where: \.isKeyWindow)
      ?? foregroundWindows.first
      ?? ASPresentationAnchor()
    #elseif canImport(AppKit)
    return
      NSApplication.shared.keyWindow
        ?? NSApplication.shared.mainWindow
        ?? NSApplication.shared.windows.first(where: \.isVisible)
        ?? NSApplication.shared.windows.first
        ?? ASPresentationAnchor()
    #endif
  }
}

#endif
