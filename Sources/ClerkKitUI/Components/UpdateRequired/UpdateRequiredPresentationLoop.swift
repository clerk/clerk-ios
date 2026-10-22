//
//  UpdateRequiredPresentationLoop.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import Observation

@MainActor
final class UpdateRequiredPresentationLoop {
  private let update: @MainActor () -> Void
  private var generation = 0
  private var updateIsScheduled = false

  private(set) var isStarted = false

  init(update: @escaping @MainActor () -> Void) {
    self.update = update
  }

  func start() {
    guard !isStarted else { return }
    isStarted = true
    generation += 1
    observe(generation: generation)
  }

  func stop() {
    isStarted = false
  }

  /// Window and scene notifications can arrive while the system is still changing
  /// windows, such as AppKit's beginSheet making the new sheet key, so they update
  /// once on the next main-queue turn instead of re-entering mid-change.
  func scheduleUpdate() {
    guard isStarted, !updateIsScheduled else { return }
    updateIsScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      updateIsScheduled = false
      if isStarted {
        update()
      }
    }
  }

  private func observe(generation: Int) {
    guard isStarted, generation == self.generation else { return }
    withObservationTracking {
      update()
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.observe(generation: generation)
      }
    }
  }
}

#endif
