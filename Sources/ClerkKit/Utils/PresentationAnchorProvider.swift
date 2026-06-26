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
    return UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    #elseif canImport(AppKit)
    return
      NSApplication.shared.keyWindow
        ?? NSApplication.shared.mainWindow
        ?? NSApplication.shared.windows.first
        ?? ASPresentationAnchor()
    #endif
  }
}

#endif
