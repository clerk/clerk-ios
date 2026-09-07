//
//  ContentView.swift
//  WatchExampleApp Watch App
//
//  Created on 2025-01-27.
//

import ClerkKit
import os
import SwiftUI

private let watchSyncLog = Logger(subsystem: "com.clerk.WatchExampleApp", category: "watch-sync")

struct ContentView: View {
  @Environment(Clerk.self) private var clerk
  @State private var operationError: String?
  @State private var isSigningOut = false

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        if let user = clerk.user {
          VStack(spacing: 8) {
            AsyncImage(url: user.imageURL) { phase in
              switch phase {
              case .success(let image):
                image
                  .resizable()
                  .scaledToFill()
              case .failure, .empty:
                Image(systemName: "person.circle.fill")
                  .resizable()
                  .foregroundColor(.secondary)
              @unknown default:
                Image(systemName: "person.circle.fill")
                  .resizable()
                  .foregroundColor(.secondary)
              }
            }
            .frame(width: 70, height: 70)
            .clipShape(.circle)

            VStack(spacing: 0) {
              if let fullName = user.fullName {
                Text(fullName)
                  .font(.caption)
                  .lineLimit(1)
              }

              if let username = user.usernameHandle {
                Text(username)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
          }

          Button {
            isSigningOut = true
            operationError = nil
            Task {
              defer { isSigningOut = false }
              do {
                try await clerk.auth.signOut(sessionId: clerk.sessionId)
              } catch {
                operationError = error.localizedDescription
              }
            }
          } label: {
            Text("Sign Out")
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .disabled(isSigningOut)
          if let operationError {
            Text(operationError)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        } else {
          VStack(spacing: 8) {
            Text("Not Signed In")
              .font(.caption)
              .fontWeight(.semibold)

            Text("Sign in on your iPhone to sync your authentication state to your Apple Watch.")
              .font(.caption2)
              .foregroundColor(.secondary)
              .lineLimit(3)
          }
          .padding(.horizontal, 8)
        }
      }
    }
    .onAppear {
      logWatchUser(clerk.userId)
    }
    .onChange(of: clerk.userId) { _, id in
      logWatchUser(id)
    }
  }

  private func logWatchUser(_ id: String?) {
    watchSyncLog.notice("clerk-watch-sync watch user=\(id ?? "nil", privacy: .public)")
  }
}

#Preview("Signed Out") {
  ContentView()
    .environment(
      Clerk.preview { preview in
        preview.isSignedIn = false
      }
    )
}

#Preview("Signed In") {
  ContentView()
    .environment(Clerk.preview())
}
