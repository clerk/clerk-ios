#if os(watchOS)
@testable import ClerkJSCore
import Testing

struct ClerkJSCoreWatchTests {
  @Test
  func invokeThrowsUnsupportedPlatform() async {
    let runtime = ClerkJSRuntime()
    await #expect(throws: ClerkJSCoreError.unsupportedPlatform) {
      try await runtime.invoke(
        ClerkJSInvocation(receiver: .clerk, method: "load", arguments: [])
      )
    }
  }
}
#endif
