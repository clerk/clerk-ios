//
//  UserButtonPopover.swift
//  Clerk
//
//  Created by Mike Pitre on 5/1/25.
//

#if os(iOS)

  import Factory
  import SwiftUI

  struct UserButtonPopover: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    @State private var error: Error?

    var sessions: [Session] {
      clerk.client?.activeSessions ?? []
    }

    var body: some View {
      VStack(spacing: 0) {
        HStack {
          Text("Account", bundle: .module)
            .font(theme.fonts.title3)
            .fontWeight(.semibold)
            .foregroundStyle(theme.colors.primary)
            .frame(minHeight: 25)
          Spacer()
          DismissButton()
        }
        .padding(16)

        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)

        ScrollView {
          VStack(spacing: 0) {
            ForEach(sessions) { session in
              if let user = session.user {
                AsyncButton {
                  //
                } label: { isRunning in
                  UserPreviewView(user: user)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)

                }
                .overlay(alignment: .bottom) {
                  Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(theme.colors.border)
                }
                .disabled(true)
              }
            }

            Button {
              //
            } label: {
              UserButtonPopoverRow(icon: "icon-cog", text: "Manage account")
            }
            .overlay(alignment: .bottom) {
              Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
            }
            .buttonStyle(.pressedBackground)

            AsyncButton {
              await signOut(sessionId: clerk.session?.id)
            } label: { isRunning in
              UserButtonPopoverRow(icon: "icon-sign-out", text: "Sign out")
                .overlayProgressView(isActive: isRunning)
            }
            .overlay(alignment: .bottom) {
              Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
            }
            .buttonStyle(.pressedBackground)
          }
        }

        SecuredByClerkView()
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(theme.colors.backgroundSecondary)
      }
      .background(theme.colors.background)
    }
  }

extension UserButtonPopover {
  
  func signOut(sessionId: String?) async {
    do {
      try await clerk.signOut(sessionId: sessionId)
      if clerk.session == nil {
        dismiss()
      }
    } catch {
      self.error = error
    }
  }
  
}

  struct UserButtonPopoverRow: View {
    @Environment(\.clerkTheme) private var theme

    let icon: String
    let text: LocalizedStringKey

    var body: some View {
      HStack(spacing: 16) {
        Image(icon, bundle: .module)
          .frame(width: 48, height: 24)
          .scaledToFit()
          .foregroundStyle(theme.colors.textSecondary)
        Text(text, bundle: .module)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.text)
          .frame(minHeight: 22)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 16)
      .padding(.horizontal, 24)
      .contentShape(.rect)
    }
  }

  #Preview {
    let _ = Container.shared.clerkService.register {
      var service = ClerkService.liveValue
      service.signOut = { _ in
        try! await Task.sleep(for: .seconds(1))
        return
      }

      return service
    }

    UserButtonPopover()
      .environment(\.clerk, .mock)
  }

#endif
