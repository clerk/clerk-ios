//
//  ClerkStateEventEmitter.swift
//  Clerk
//

import Foundation

@MainActor
enum ClerkStateEvent {
  case authChanged(previousClient: Client?, client: Client?)
  case environmentChanged
  case deviceTokenSet(previousToken: String?, token: String)
  case foregrounded
}

@MainActor
protocol ClerkStateEventObserver: AnyObject {
  func handle(_ event: ClerkStateEvent, from clerk: Clerk) throws
  func cancel()
  func cancelAndWait() async
}

@MainActor
struct ClerkStateEventEmitter {
  private var observers: [any ClerkStateEventObserver] = []

  mutating func addObserver(_ observer: any ClerkStateEventObserver) {
    observers.append(observer)
  }

  mutating func removeAllObservers() {
    observers.removeAll()
  }

  func emit(_ event: ClerkStateEvent, from clerk: Clerk) throws {
    var firstError: Error?

    for observer in observers {
      do {
        try observer.handle(event, from: clerk)
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

  func cancelObservers() {
    for observer in observers {
      observer.cancel()
    }
  }

  func cancelObserversAndWait() async {
    for observer in observers {
      await observer.cancelAndWait()
    }
  }
}
