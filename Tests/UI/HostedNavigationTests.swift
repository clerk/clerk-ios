@_spi(FrameworkIntegration) @testable import ClerkKitUI
import Testing

@MainActor
struct HostedNavigationTests {
  @Test
  func reportDepthForwardsToOnDepthChange() {
    let hostedNavigation = ClerkHostedNavigation()
    var received: [Int] = []
    hostedNavigation.onDepthChange = { received.append($0) }

    hostedNavigation.reportDepth(1)
    hostedNavigation.reportDepth(0)

    #expect(received == [1, 0])
  }

  @Test
  func popRoutesToRegisteredHandler() {
    let hostedNavigation = ClerkHostedNavigation()
    var pops: [Bool] = []
    hostedNavigation.register { toRoot in pops.append(toRoot) }

    hostedNavigation.pop()
    hostedNavigation.popToRoot()

    #expect(pops == [false, true])
  }

  @Test
  func popIsNoOpWithoutRegisteredHandler() {
    let hostedNavigation = ClerkHostedNavigation()

    hostedNavigation.pop()
    hostedNavigation.popToRoot()
  }

  @Test
  func unregisterStopsRoutingPops() {
    let hostedNavigation = ClerkHostedNavigation()
    var pops: [Bool] = []
    hostedNavigation.register { toRoot in pops.append(toRoot) }
    hostedNavigation.unregister()

    hostedNavigation.pop()

    #expect(pops.isEmpty)
  }

  @Test
  func lastRegisteredHandlerWins() {
    let hostedNavigation = ClerkHostedNavigation()
    var first = 0
    var second = 0
    hostedNavigation.register { _ in first += 1 }
    hostedNavigation.register { _ in second += 1 }

    hostedNavigation.pop()

    #expect(first == 0)
    #expect(second == 1)
  }
}
