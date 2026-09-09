#if os(iOS) || os(macOS)
import ClerkKit
import Observation

@MainActor @Observable
final class UserProfileData {
  private(set) var sessions: [SessionWithActivities] = []
  private var request = 0
  private var userID: String?

  func refresh(user: User?) async throws {
    request += 1
    let currentRequest = request
    if userID != user?.id { sessions = []; userID = user?.id }
    guard let user else { return }
    let result = try await user.getSessions()
    try Task.checkCancellation()
    guard currentRequest == request else { return }
    sessions = result
  }
}
#endif
