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
  ) async -> Bool {
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

    // AppKit never calls the sheet's completion when the window under it closes, or when a
    // sheet under it ends.
    var observers: [any NSObjectProtocol] = []
    let finish = OneTimeAction<Void> { _ in
      observers.forEach(NotificationCenter.default.removeObserver)
      sheet.contentViewController = nil
      onDismiss()
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification,
      object: window,
      queue: .main
    ) { _ in
      MainActor.assumeIsolated {
        sheet.sheetParent?.endSheet(sheet)
        finish(())
      }
    })
    var ancestor: NSWindow? = parent
    while let current = ancestor {
      observers.append(NotificationCenter.default.addObserver(
        forName: NSWindow.didEndSheetNotification,
        object: current,
        queue: .main
      ) { _ in
        // AppKit clears an ended sheet's parent only after this notification, and its
        // completion may queue that sheet again, so the check waits for the next turn.
        Task { @MainActor in
          if !Self.isAttached(sheet, to: window) {
            finish(())
          }
        }
      })
      ancestor = current.sheetParent
    }
    parent.beginSheet(sheet) { _ in
      finish(())
    }
    return true
  }

  private static func isAttached(_ sheet: NSWindow, to window: NSWindow) -> Bool {
    var child = sheet
    while let parent = child.sheetParent {
      guard parent.sheets.contains(child) else { return false }
      child = parent
    }
    return child === window
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
