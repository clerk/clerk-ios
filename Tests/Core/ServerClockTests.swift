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
}
