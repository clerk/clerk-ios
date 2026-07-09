@_spi(FrameworkIntegration) @testable import ClerkKitUI
import Testing

@MainActor
struct EmbeddedNavigationTests {
  @Test
  func reportDepthForwardsToOnDepthChange() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var received: [Int] = []
    embeddedNavigation.onDepthChange = { received.append($0) }

    embeddedNavigation.reportDepth(1)
    embeddedNavigation.reportDepth(0)

    #expect(received == [1, 0])
  }

  @Test
  func popRoutesToRegisteredHandler() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var pops: [Bool] = []
    embeddedNavigation.register { toRoot in pops.append(toRoot) }

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
    embeddedNavigation.register { toRoot in pops.append(toRoot) }
    embeddedNavigation.unregister()

    embeddedNavigation.pop()

    #expect(pops.isEmpty)
  }

  @Test
  func lastRegisteredHandlerWins() {
    let embeddedNavigation = ClerkEmbeddedNavigation()
    var first = 0
    var second = 0
    embeddedNavigation.register { _ in first += 1 }
    embeddedNavigation.register { _ in second += 1 }

    embeddedNavigation.pop()

    #expect(first == 0)
    #expect(second == 1)
  }
}
