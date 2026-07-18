//
//  ClerkInternalStateChangeEmitter.swift
//  Clerk
//

import Foundation

@MainActor
enum ClerkInternalStateChange {
  case clientDidChange(previous: Client?, current: Client?)
  case environmentDidChange
  case deviceTokenDidChange(previous: String?, current: String?)
  case sharedSessionIdentityDidChange
  case localStorageDidClear
  case applicationDidEnterForeground
}

@MainActor
protocol ClerkInternalStateChangeObserver: AnyObject {
  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws
}

@MainActor
struct ClerkInternalStateChangeEmitter {
  private var observers: [any ClerkInternalStateChangeObserver] = []

  mutating func addObserver(_ observer: any ClerkInternalStateChangeObserver) {
    observers.append(observer)
  }

  mutating func removeAllObservers() {
    observers.removeAll()
  }

  func emit(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    var firstError: Error?

    for observer in observers {
      do {
        try observer.handle(change, from: clerk)
      } catch {
        if firstError == nil {
          firstError = error
        }
      }
    }

    if let firstError {
      throw firstError
    }
  }
}
