import Foundation

// UserDefaults performs its own internal synchronization, so it can be shared
// safely across concurrency domains. We explicitly mark it as sendable until
// the SDK adopts Sendable conformance itself.
extension UserDefaults: @unchecked @retroactive Sendable {}
