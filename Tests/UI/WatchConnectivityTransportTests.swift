#if os(iOS)

@testable import ClerkKit
import Foundation
import Testing
import WatchConnectivity

@MainActor
@Suite(.serialized)
struct WatchConnectivityTransportTests {
  @Test
  func forwardsSessionCallbacksToTheAppsDelegate() throws {
    try #require(WCSession.isSupported())
    let appDelegate = AppSessionDelegate()
    WCSession.default.delegate = appDelegate
    let transport = WatchConnectivityTransport(onReceive: { _ in }, onActivate: {})
    let sessionDelegate: any WCSessionDelegate = transport

    #expect(WCSession.default.delegate === transport)
    #expect(transport.responds(to: NSSelectorFromString("session:didReceiveMessage:")))
    #expect(!transport.responds(to: NSSelectorFromString("session:didReceiveUserInfo:")))

    sessionDelegate.session?(WCSession.default, didReceiveMessage: ["message": 1])
    sessionDelegate.session?(WCSession.default, didReceiveApplicationContext: ["context": 1])

    #expect(appDelegate.receivedMessages.map(\.keys.first) == ["message"])
    #expect(appDelegate.receivedContexts.map(\.keys.first) == ["context"])
  }

  @Test
  func replacingTheTransportKeepsForwardingToTheAppsDelegate() throws {
    try #require(WCSession.isSupported())
    let appDelegate = AppSessionDelegate()
    WCSession.default.delegate = appDelegate
    let first = WatchConnectivityTransport(onReceive: { _ in }, onActivate: {})
    let second = WatchConnectivityTransport(onReceive: { _ in }, onActivate: {})

    withExtendedLifetime(first) {
      second.session(WCSession.default, didReceiveApplicationContext: ["context": 1])
    }

    #expect(WCSession.default.delegate === second)
    #expect(appDelegate.receivedContexts.count == 1)
  }
}

private final class AppSessionDelegate: NSObject, WCSessionDelegate {
  private(set) var receivedMessages: [[String: Any]] = []
  private(set) var receivedContexts: [[String: Any]] = []

  func session(_: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {}

  func sessionDidBecomeInactive(_: WCSession) {}

  func sessionDidDeactivate(_: WCSession) {}

  func session(_: WCSession, didReceiveMessage message: [String: Any]) {
    receivedMessages.append(message)
  }

  func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    receivedContexts.append(applicationContext)
  }
}

#endif
