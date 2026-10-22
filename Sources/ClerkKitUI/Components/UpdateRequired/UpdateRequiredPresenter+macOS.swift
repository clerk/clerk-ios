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
  private var isStarted = false
  private var observationGeneration = 0
  private var sheets: [ObjectIdentifier: NSWindow] = [:]
  private var windowObservers: [NSObjectProtocol] = []

  func start(clerk: Clerk) {
    self.clerk = clerk
    guard !isStarted else {
      update()
      return
    }

    isStarted = true
    observationGeneration += 1
    observeWindows()
    observeStatus(generation: observationGeneration)
  }

  func stop() {
    isStarted = false
    windowObservers.forEach(NotificationCenter.default.removeObserver)
    windowObservers = []
    hideAll()
  }

  private func observeStatus(generation: Int) {
    guard isStarted, generation == observationGeneration else { return }
    withObservationTracking {
      update()
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.observeStatus(generation: generation)
      }
    }
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
          self?.update()
        }
      }
    }
    windowObservers.append(
      center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] notification in
        guard let window = notification.object as? NSWindow else { return }
        let windowID = ObjectIdentifier(window)
        MainActor.assumeIsolated {
          self?.sheets[windowID] = nil
        }
      }
    )
  }

  private func update() {
    guard isStarted, let clerk, !clerk.appVersionSupportStatus.isSupported else {
      hideAll()
      return
    }

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
    sheet.setContentSize(Self.sheetSize)

    // A window shows one sheet at a time, and a new one waits for the current one
    // to end, so the update sheet goes on top of any sheet the app already shows.
    var parent = window
    while let attachedSheet = parent.attachedSheet {
      parent = attachedSheet
    }
    // beginSheet makes the sheet key at once, which posts didBecomeKey and runs
    // update() again, so the sheet is recorded before it begins.
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
