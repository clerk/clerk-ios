import ClerkKit
import ClerkKitUI
import SwiftUI

/// A deterministic UI-test application. No fixture capability is included in the SDK targets.
@main
struct AuthJourneyApp: App {
  @State private var connection = JourneyConnection()

  var body: some Scene {
    WindowGroup {
      Group {
        if let clerk = connection.clerk, let host = connection.host {
          VStack(spacing: 0) {
            Group {
              if clerk.isAuthFlowComplete {
                Text("Signed in through the core")
                  .accessibilityIdentifier("journey.completed")
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              } else {
                AuthView(mode: .signIn, isDismissible: false) { connection.completions += 1 }
                  .persistsIdentifiers(false)
              }
            }
            Text("session=\(clerk.session?.status.rawValue ?? "none"); user=\(clerk.user?.id ?? "none"); completions=\(connection.completions); touches=\(host.touches); codes=\(host.attemptedCodes.joined(separator: ","))")
              .font(.caption2)
              .padding(8)
              .accessibilityIdentifier("journey.state")
          }
          .environment(clerk)
        } else if let error = connection.error {
          Text(error).accessibilityIdentifier("journey.failure")
        } else {
          ProgressView("Connecting to packaged core")
        }
      }
      .task { await connection.connect() }
    }
  }
}

@MainActor @Observable
private final class JourneyConnection {
  var clerk: Clerk?
  var host: EmailCodeJourneyHost?
  var error: String?
  var completions = 0

  func connect() async {
    guard clerk == nil, host == nil else { return }
    do {
      guard let url = Bundle.main.url(forResource: "fapi", withExtension: "json") else {
        throw CoreError(code: "missing_journey_fixture")
      }
      let host = try EmailCodeJourneyHost(data: Data(contentsOf: url))
      self.host = host
      let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
      clerk = try await Clerk.connect(
        configuration: .init(publishableKey: key, callbackURL: URL(string: "clerk-journey://callback")!),
        capabilities: host
      )
    } catch {
      self.error = error.localizedDescription
    }
  }
}
