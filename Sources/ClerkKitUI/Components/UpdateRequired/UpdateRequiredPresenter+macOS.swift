//
//  UpdateRequiredPresenter+macOS.swift
//  Clerk
//

#if os(macOS)

import AppKit
import ClerkKit
import SwiftUI

@objc(ClerkKitUIAutomaticPresenter)
@MainActor
final class UpdateRequiredPresenter: NSObject, ClerkAutomaticPresenter {
  private static let sheetSize = NSSize(width: 440, height: 600)

  private weak var clerk: Clerk?
  private lazy var loop = UpdateRequiredPresentationLoop { [weak self] in
    self?.update()
  }

  private var sheets: [ObjectIdentifier: NSWindow] = [:]
  private var windowObservers: [NSObjectProtocol] = []

  func start(clerk: Clerk) {
    self.clerk = clerk
    guard !loop.isStarted else {
      update()
      return
    }

    observeWindows()
    loop.start()
  }

  func stop() {
    loop.stop()
    windowObservers.forEach(NotificationCenter.default.removeObserver)
    windowObservers = []
    hideAll()
  }

  /// AppKit has no notification for a new window, so the presenter checks again
  /// whenever a window becomes key or main, which every new window does.
  private func observeWindows() {
    let center = NotificationCenter.default
    windowObservers = [
      NSWindow.didBecomeKeyNotification,
      NSWindow.didBecomeMainNotification,
      NSApplication.didBecomeActiveNotification,
    ].map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.loop.scheduleUpdate()
        }
      }
    }
    windowObservers.append(
      center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] notification in
        guard let window = notification.object as? NSWindow else { return }
        let windowID = ObjectIdentifier(window)
        MainActor.assumeIsolated {
          guard let self else { return }
          self.sheets[windowID] = nil
          self.sheets = self.sheets.filter { ObjectIdentifier($0.value) != windowID }
          self.loop.scheduleUpdate()
        }
      }
    )
  }

  private func update() {
    guard loop.isStarted, let clerk, !clerk.appVersionSupportStatus.isSupported else {
      hideAll()
      return
    }

    sheets = sheets.filter { $0.value.sheetParent != nil || $0.value.isVisible }

    for window in NSApplication.shared.windows where needsSheet(window) {
      show(on: window, clerk: clerk)
    }
  }

  private func needsSheet(_ window: NSWindow) -> Bool {
    window.isVisible
      && window.canBecomeMain
      && window.sheetParent == nil
      && !window.isSheet
      && !(window is NSPanel)
      && !sheets.values.contains { $0 === window }
      && sheets[ObjectIdentifier(window)] == nil
  }

  private func show(on window: NSWindow, clerk: Clerk) {
    let hostingController = NSHostingController(rootView: PresentedUpdateRequiredView().environment(clerk))
    let sheet = NSWindow(contentViewController: hostingController)
    // Not closable, so File > Close can't end the sheet while the window stays open.
    sheet.styleMask = [.titled]
    sheet.setContentSize(Self.sheetSize)

    // A window shows one sheet at a time, and a new one waits for the current one
    // to end, so the update sheet goes on top of any sheet the app already shows.
    var parent = window
    while let attachedSheet = parent.attachedSheet {
      parent = attachedSheet
    }
    // Recorded before beginSheet, which makes the sheet key at once, so no update
    // that runs before it returns can treat this window as uncovered.
    sheets[ObjectIdentifier(window)] = sheet
    parent.beginSheet(sheet)
  }

  private func hideAll() {
    guard !sheets.isEmpty else { return }

    let shownSheets = Array(sheets.values)
    sheets = [:]
    for sheet in shownSheets {
      sheet.sheetParent?.endSheet(sheet)
      sheet.orderOut(nil)
    }
  }
}

#endif
