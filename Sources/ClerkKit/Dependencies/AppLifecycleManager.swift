import Foundation

#if canImport(UIKit)
import UIKit
#endif

final class AppLifecycleManager {
  private let notificationCenter: NotificationCenter
  private var telemetry: TelemetryCollector

  private var willEnterForegroundTask: Task<Void, Never>?
  private var didEnterBackgroundTask: Task<Void, Never>?
  private var sessionPollingTask: Task<Void, Never>?

  init(
    notificationCenter: NotificationCenter = .default,
    telemetry: TelemetryCollector
  ) {
    self.notificationCenter = notificationCenter
    self.telemetry = telemetry

    Task { @MainActor in
      setupNotificationObservers()
      startSessionTokenPolling()
    }
  }

  @MainActor
  func setupNotificationObservers() {
    #if !os(watchOS) && !os(macOS)
    willEnterForegroundTask = Task { [weak self] in
      guard let self else { return }

      let notifications = notificationCenter.notifications(
        named: UIApplication.willEnterForegroundNotification
      )

      for await _ in notifications {
        await MainActor.run { [weak self] in
          self?.startSessionTokenPolling()
        }

        Task { @MainActor in
          try? await Client.get()
        }

        Task { @MainActor in
          try? await Clerk.Environment.get()
        }
      }
    }

    didEnterBackgroundTask = Task { [weak self] in
      guard let self else { return }

      let notifications = notificationCenter.notifications(
        named: UIApplication.didEnterBackgroundNotification
      )

      for await _ in notifications {
        await MainActor.run { [weak self] in
          self?.stopSessionTokenPolling()
        }

        Task {
          await self.telemetry.flush()
        }
      }
    }
    #endif
  }

  func cancelNotificationObservers() {
    willEnterForegroundTask?.cancel()
    willEnterForegroundTask = nil

    didEnterBackgroundTask?.cancel()
    didEnterBackgroundTask = nil
  }

  func startSessionTokenPolling() {
    guard sessionPollingTask == nil || sessionPollingTask?.isCancelled == true else {
      return
    }

    sessionPollingTask = Task(priority: .background) { @MainActor in
      repeat {
        let session = Clerk.shared.session
        if let session {
          _ = try? await session.getToken()
        }
        try? await Task.sleep(for: .seconds(5), tolerance: .seconds(0.1))
      } while !Task.isCancelled
    }
  }

  func stopSessionTokenPolling() {
    sessionPollingTask?.cancel()
    sessionPollingTask = nil
  }

}
