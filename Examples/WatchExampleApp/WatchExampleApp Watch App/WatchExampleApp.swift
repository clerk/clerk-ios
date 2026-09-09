import ClerkKit
import SwiftUI

@main
struct WatchExampleAppWatchApp: App {
  @State private var clerk: Clerk?
  @State private var connectionError: String?

  var body: some Scene {
    WindowGroup {
      Group {
        if let clerk {
          ContentView().environment(clerk)
        } else if let connectionError {
          VStack(spacing: 12) {
            Image(systemName: "applewatch.slash")
            Text("Authentication unavailable").font(.headline)
            Text(connectionError).font(.caption)
          }.padding()
        } else {
          ProgressView("Connecting…")
        }
      }
      .task {
        guard clerk == nil, connectionError == nil else { return }
        do {
          let configuration = try ClerkConfiguration(
            publishableKey: WatchExampleLocalSecrets.load().publishableKey ?? "",
            callbackURL: URL(string: "com.clerk.WatchExample.watch://oauth/callback")!
          )
          clerk = try await Clerk.connect(configuration: configuration)
        } catch let error as CoreError where error.code == "capability_unavailable:embedded_engine" {
          connectionError = "This prerelease has no authentication runtime on Apple Watch. Phone-to-watch sign-in synchronization is unavailable."
        } catch {
          connectionError = error.localizedDescription
        }
      }
    }
  }
}
