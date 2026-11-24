//
//  ReverificationSheetDisplay+macOS.swift
//  Clerk
//

#if os(macOS)

import AppKit
import ClerkKit
import SwiftUI

@MainActor
struct PlatformReverificationSheetDisplay: ReverificationSheetDisplay {
  func show(
    _ request: ReverificationRequest,
    clerk: Clerk,
    onDismiss: @escaping @MainActor () -> Void
  ) -> Bool {
    guard let window = presentingWindow() else { return false }

    // A window shows one sheet at a time, and a new one waits for the current one to end, so
    // the sheet goes on top of any sheet the app already shows.
    var parent = window
    while let attachedSheet = parent.attachedSheet {
      parent = attachedSheet
    }

    let sheet = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
    let content = NSHostingController(
      rootView: PresentedReverificationView(clerk: clerk, request: request) { [weak sheet] in
        guard let sheet else { return }
        sheet.sheetParent?.endSheet(sheet)
      }
    )
    sheet.contentViewController = content
    sheet.setContentSize(content.view.fittingSize)
    parent.beginSheet(sheet) { _ in
      sheet.contentViewController = nil
      onDismiss()
    }
    return true
  }

  /// AppKit has no key or main window while the app is inactive, so the frontmost window that
  /// can be main stands in for them.
  private func presentingWindow() -> NSWindow? {
    let app = NSApplication.shared
    return app.keyWindow ?? app.mainWindow ?? app.orderedWindows.first { window in
      window.isVisible && window.canBecomeMain && !window.isSheet && !(window is NSPanel)
    }
  }
}

#endif
