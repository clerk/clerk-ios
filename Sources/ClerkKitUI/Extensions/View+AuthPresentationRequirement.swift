#if os(iOS)

import ClerkKit
import SwiftUI

private struct AuthPresentationRequirementModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk

  let action: @MainActor (Clerk.AuthPresentationRequirement) -> Void

  func body(content: Content) -> some View {
    content
      .onChange(of: clerk.authPresentationRequirement, initial: true) { _, requirement in
        guard let requirement else { return }
        action(requirement)
      }
  }
}

extension View {
  /// Notifies the host when Clerk determines that auth UI presentation is required.
  ///
  /// Use this to trigger presentation of ``AuthView`` from your own sheet or full-screen
  /// cover without giving the SDK ownership of presentation policy.
  public func onAuthPresentationRequirement(
    perform action: @escaping @MainActor (Clerk.AuthPresentationRequirement) -> Void
  ) -> some View {
    modifier(AuthPresentationRequirementModifier(action: action))
  }
}

#endif
