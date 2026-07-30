@_spi(FrameworkIntegration) @testable import ClerkKitUI
import Testing

@MainActor
struct EmbeddedNavigationTests {
  @Test
  func reportDepthForwardsToOnDepthChange() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var received: [Int] = []
    embeddedNavigation.onDepthChange = { received.append($0) }
    let registration = embeddedNavigation.register { _ in }

    embeddedNavigation.reportDepth(1, from: registration)
    embeddedNavigation.reportDepth(0, from: registration)

    #expect(received == [1, 0])
  }

  @Test
  func popRoutesToRegisteredHandler() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var pops: [Bool] = []
    _ = embeddedNavigation.register { toRoot in pops.append(toRoot) }

    embeddedNavigation.pop()
    embeddedNavigation.popToRoot()

    #expect(pops == [false, true])
  }

  @Test
  func popIsNoOpWithoutRegisteredHandler() {
    let embeddedNavigation = ClerkEmbeddedNavigation()

    embeddedNavigation.pop()
    embeddedNavigation.popToRoot()
  }

  @Test
  func unregisterStopsRoutingPops() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var pops: [Bool] = []
    let registration = embeddedNavigation.register { toRoot in pops.append(toRoot) }
    embeddedNavigation.unregister(registration)

    embeddedNavigation.pop()

    #expect(pops.isEmpty)
  }

  @Test
  func lastRegisteredHandlerWins() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var first = 0
    var second = 0
    _ = embeddedNavigation.register { _ in first += 1 }
    _ = embeddedNavigation.register { _ in second += 1 }

    embeddedNavigation.pop()

    #expect(first == 0)
    #expect(second == 1)
  }

  @Test
  func staleUnregisterDoesNotTearDownSuccessor() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var pops: [Bool] = []
    let old = embeddedNavigation.register { _ in }
    _ = embeddedNavigation.register { toRoot in pops.append(toRoot) }

    // An older component disappearing after its successor registered must not
    // clear the successor's handler.
    embeddedNavigation.unregister(old)
    embeddedNavigation.pop()

    #expect(pops == [false])
  }

  @Test
  func staleDepthReportsAreIgnored() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var received: [Int] = []
    embeddedNavigation.onDepthChange = { received.append($0) }
    let old = embeddedNavigation.register { _ in }
    let current = embeddedNavigation.register { _ in }

    embeddedNavigation.reportDepth(3, from: old)
    embeddedNavigation.reportDepth(1, from: current)

    #expect(received == [1])
  }
}
