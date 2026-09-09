@testable import NativeCoreProof
import Testing

@MainActor struct PackagedCoreTests {
  @Test func generatedResourcesExecuteThePackagedCore() async throws {
    try await PackageProof.run()
  }
}
