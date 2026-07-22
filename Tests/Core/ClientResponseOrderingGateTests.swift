@testable import ClerkKit
import Foundation
import Testing

struct ClientResponseOrderingGateTests {
  @Test
  func rejectsOlderSequenceWithoutNewerServerState() {
    let date = Date(timeIntervalSince1970: 100)
    var gate = ClientResponseOrderingGate()
    gate.record(sequence: 2, serverDate: date)

    #expect(!gate.accepts(
      sequence: 1,
      serverDate: date,
      incomingUpdatedAt: date,
      currentUpdatedAt: date
    ))
  }

  @Test
  func acceptsOlderSequenceWithNewerServerDate() {
    let date = Date(timeIntervalSince1970: 100)
    var gate = ClientResponseOrderingGate()
    gate.record(sequence: 2, serverDate: date)

    #expect(gate.accepts(
      sequence: 1,
      serverDate: date.addingTimeInterval(1),
      incomingUpdatedAt: date,
      currentUpdatedAt: date
    ))
  }

  @Test
  func equalServerDateUsesClientUpdatedAt() {
    let date = Date(timeIntervalSince1970: 100)
    var gate = ClientResponseOrderingGate()
    gate.record(sequence: 2, serverDate: date)

    #expect(gate.accepts(
      sequence: 1,
      serverDate: date,
      incomingUpdatedAt: date.addingTimeInterval(1),
      currentUpdatedAt: date
    ))
  }

  @Test
  func resetClearsOrderingWatermarks() {
    let date = Date(timeIntervalSince1970: 100)
    var gate = ClientResponseOrderingGate()
    gate.record(sequence: 2, serverDate: date)

    gate.reset()

    #expect(gate.lastAcceptedSequence == nil)
    #expect(gate.lastAcceptedServerDate == nil)
  }

  @Test
  func resetSequencePreservesServerWatermark() {
    let date = Date(timeIntervalSince1970: 100)
    var gate = ClientResponseOrderingGate()
    gate.record(sequence: 2, serverDate: date)

    gate.resetSequence()

    #expect(gate.lastAcceptedSequence == nil)
    #expect(gate.lastAcceptedServerDate == date)
  }
}
