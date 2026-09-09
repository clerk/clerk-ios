import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor func observeApplicationLifecycle(_ runtime: CoreRuntime) {
  #if canImport(UIKit) && !os(watchOS)
  let foreground = UIApplication.didBecomeActiveNotification
  let background = UIApplication.willResignActiveNotification
  runtime.setApplicationActive(UIApplication.shared.applicationState == .active)
  #elseif canImport(AppKit)
  let foreground = NSApplication.didBecomeActiveNotification
  let background = NSApplication.willResignActiveNotification
  runtime.setApplicationActive(NSApplication.shared.isActive)
  #else
  return
  #endif
  #if (canImport(UIKit) && !os(watchOS)) || canImport(AppKit)
  let center = NotificationCenter.default
  let active = center.addObserver(forName: foreground, object: nil, queue: .main) { [weak runtime] _ in
    Task { @MainActor in runtime?.setApplicationActive(true) }
  }
  let inactive = center.addObserver(forName: background, object: nil, queue: .main) { [weak runtime] _ in
    Task { @MainActor in runtime?.setApplicationActive(false) }
  }
  runtime.addTeardown { center.removeObserver(active); center.removeObserver(inactive) }
  #endif
}
