@testable import ClerkKit
import Foundation
import Testing

struct ServerClockTests {
  private let receivedAt = Date(timeIntervalSince1970: 1000)

  @Test
  func usesTheDeviceClockBeforeAnyResponse() {
    #expect(ServerClock().deviceLag == 0)
  }

  @Test
  func recordsHowFarTheDeviceLagsTheServer() {
    var clock = ServerClock()

    clock.record(serverDate: receivedAt.addingTimeInterval(300), receivedAt: receivedAt)

    #expect(clock.deviceLag == 300)
  }

  @Test
  func serverDateBehindTheDeviceCountsAsNoLag() {
    var clock = ServerClock()

    clock.record(serverDate: receivedAt.addingTimeInterval(-300), receivedAt: receivedAt)

    #expect(clock.deviceLag == 0)
  }

  @Test
  func latestResponseReplacesAnEarlierLag() {
    var clock = ServerClock()
    clock.record(serverDate: receivedAt.addingTimeInterval(300), receivedAt: receivedAt)

    clock.record(serverDate: receivedAt, receivedAt: receivedAt)

    #expect(clock.deviceLag == 0)
  }

  @Test
  func proofsUseTheDeviceClockBeforeAnyResponse() {
    let before = Date.now

    let proofDate = ServerClock().proofDate()

    #expect(proofDate >= before)
    #expect(proofDate <= .now)
  }

  @Test
  func proofsCountForwardFromTheLastServerDate() {
    var clock = ServerClock()
    let instant = ContinuousClock.now
    clock.record(serverDate: receivedAt.addingTimeInterval(-600), receivedAt: receivedAt, receivedAtInstant: instant)

    let proofDate = clock.proofDate(at: instant.advanced(by: .milliseconds(2500)))

    #expect(proofDate == receivedAt.addingTimeInterval(-597.5))
  }

  @Test
  func proofsIgnoreTheDeviceWallClock() {
    var clock = ServerClock()
    let instant = ContinuousClock.now
    let serverDate = Date.now.addingTimeInterval(3600)
    clock.record(serverDate: serverDate, receivedAt: .now, receivedAtInstant: instant)

    #expect(clock.proofDate(at: instant) == serverDate)
  }
}
