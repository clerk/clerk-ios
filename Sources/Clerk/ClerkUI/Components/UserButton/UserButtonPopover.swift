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

    @State private var accountSwitcherIsPresented = false
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
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 25)
          Spacer()
          DismissButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)

        ScrollView {
          VStack(spacing: 0) {
            if let user = clerk.user {
              UserPreviewView(user: user)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .overlay(alignment: .bottom) {
                  Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(theme.colors.border)
                }
            }

            Button {
              //
            } label: {
              UserProfileRowView(icon: "icon-cog", text: "Manage account")
            }
            .overlay(alignment: .bottom) {
              Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
            }
            .buttonStyle(.pressedBackground)
            .simultaneousGesture(TapGesture())

            if clerk.environment.mutliSessionModeIsEnabled {
              Button {
                accountSwitcherIsPresented = true
              } label: {
                UserProfileRowView(icon: "icon-switch", text: "Switch account")
              }
              .overlay(alignment: .bottom) {
                Rectangle()
                  .frame(height: 1)
                  .foregroundStyle(theme.colors.border)
              }
              .buttonStyle(.pressedBackground)
              .simultaneousGesture(TapGesture())
            }

            AsyncButton {
              guard let sessionId = clerk.session?.id else { return }
              await signOut(sessionId: sessionId)
            } label: { isRunning in
              UserProfileRowView(icon: "icon-sign-out", text: "Sign out")
                .overlayProgressView(isActive: isRunning)
            }
            .overlay(alignment: .bottom) {
              Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
            }
            .buttonStyle(.pressedBackground)
            .simultaneousGesture(TapGesture())
          }
        }

        SecuredByClerkView()
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(theme.colors.backgroundSecondary)
      }
      .background(theme.colors.background)
      .clerkErrorPresenting($error)
      .sheet(isPresented: $accountSwitcherIsPresented) {
        UserButtonAccountSwitcher()
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.hidden)
      }
    }
  }

  extension UserButtonPopover {

    func signOut(sessionId: String) async {
      do {
        try await clerk.signOut(sessionId: sessionId)
        if clerk.session == nil {
          dismiss()
        }
      } catch {
        self.error = error
        ClerkLogger.error("Failed to sign out from popover", error: error)
      }
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
