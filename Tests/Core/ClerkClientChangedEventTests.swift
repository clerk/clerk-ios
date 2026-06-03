@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct ClerkClientChangedEventTests {
  @Test
  func settingDifferentClientEmitsClientChangedEvent() async throws {
    let clerk = Clerk()
    let client = Client.mock

    let event = try await captureNextClientChangedEvent(from: clerk) {
      clerk.client = client
    }

    #expect(event?.oldValue == nil)
    #expect(event?.newValue == client)
  }

  @Test
  func settingEquivalentClientDoesNotEmitClientChangedEvent() async throws {
    let clerk = Clerk()
    let client = Client.mock
    clerk.client = client

    let event = try await captureNextClientChangedEvent(from: clerk) {
      clerk.client = client
    }

    #expect(event == nil)
  }

  @Test
  func mutatingNestedClientPropertyEmitsClientChangedEvent() async throws {
    let clerk = Clerk()
    let client = Client.mock
    clerk.client = client

    let event = try await captureNextClientChangedEvent(from: clerk) {
      clerk.client?.sessions[0].user?.firstName = "Updated"
    }

    #expect(event?.oldValue?.sessions[0].user?.firstName == client.sessions[0].user?.firstName)
    #expect(event?.newValue?.sessions[0].user?.firstName == "Updated")
  }

  private func captureNextClientChangedEvent(
    from clerk: Clerk,
    timeout: Duration = .milliseconds(250),
    operation: () async throws -> Void
  ) async throws -> ClientChangedValues? {
    let captured = LockIsolated<ClientChangedValues?>(nil)
    var listener: Task<Void, Never>?
    await withCheckedContinuation { (ready: CheckedContinuation<Void, Never>) in
      listener = Task { @MainActor in
        var iterator = clerk.auth.events.makeAsyncIterator()
        ready.resume()
        while let event = await iterator.next() {
          guard case .clientChanged(let oldValue, let newValue) = event else {
            continue
          }
          captured.setValue(ClientChangedValues(oldValue: oldValue, newValue: newValue))
          break
        }
      }
    }
    defer { listener?.cancel() }

    try await operation()

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if let event = captured.value {
        return event
      }

      try await Task.sleep(for: .milliseconds(10))
    }

    return captured.value
  }
}

private struct ClientChangedValues: Equatable {
  let oldValue: Client?
  let newValue: Client?
}
