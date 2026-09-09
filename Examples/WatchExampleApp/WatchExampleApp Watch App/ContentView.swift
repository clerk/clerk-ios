//
//  ContentView.swift
//  WatchExampleApp Watch App
//
//  Created on 2025-01-27.
//

import ClerkKit
import SwiftUI

struct ContentView: View {
  @State private var errorMessage: String?
  @Environment(Clerk.self) private var clerk

  var fullName: String? {
    let name = [clerk.user?.firstName, clerk.user?.lastName]
      .compactMap(\.self)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return name.isEmpty ? nil : name
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        if let user = clerk.user, clerk.session?.status == .active, clerk.session?.currentTask == nil {
          VStack(spacing: 8) {
            AsyncImage(url: URL(string: user.imageUrl)) { phase in
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
              if let fullName {
                Text(fullName)
                  .font(.caption)
                  .lineLimit(1)
              }

              if let username = user.username, !username.isEmpty {
                Text(username)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
          }

          Button {
            Task {
              do { try await clerk.signOut() }
              catch { errorMessage = error.localizedDescription }
            }
          } label: {
            Text("Sign Out")
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        } else {
          VStack(spacing: 8) {
            Text("Not Signed In")
              .font(.caption)
              .fontWeight(.semibold)

            Text("Phone-to-watch authentication synchronization is unavailable in this prerelease.")
              .font(.caption2)
              .foregroundColor(.secondary)
              .lineLimit(3)
          }
          .padding(.horizontal, 8)
        }
      }
    }
    .alert("Unable to sign out", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
      Button("OK") { errorMessage = nil }
    } message: { Text(errorMessage ?? "") }
  }
}
