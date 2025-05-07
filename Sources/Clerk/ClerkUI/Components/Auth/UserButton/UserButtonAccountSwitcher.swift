//
//  UserButtonAccountSwitcher.swift
//  Clerk
//
//  Created by Mike Pitre on 5/6/25.
//

#if os(iOS)

  import SwiftUI

  struct UserButtonAccountSwitcher: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var authViewIsPresented = false
    @State private var error: Error?

    var sessions: [Session] {
      (clerk.client?.sessions ?? [])
        .sorted { lhs, rhs in
          if lhs.id == clerk.session?.id {
            return true
          } else if rhs.id == clerk.session?.id {
            return false
          } else {
            return false
          }
        }
    }

    func setActiveSession(_ session: Session) async {
      do {
        try await clerk.setActive(sessionId: session.id)
        dismiss()
      } catch {
        self.error = error
      }
    }

    func signOutOfAllAccounts() async {
      do {
        try await clerk.signOut()
      } catch {
        self.error = error
      }
    }

    var body: some View {
      VStack(spacing: 0) {
        HStack {
          Button {
            //
          } label: {
            Text("Done", bundle: .module)
              .font(theme.fonts.body)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.primary)
          }
          .opacity(0)
          .disabled(true)

          Spacer()

          Text("Switch account", bundle: .module)
            .font(theme.fonts.headline)
            .foregroundStyle(theme.colors.text)
            .frame(minHeight: 25)

          Spacer()

          Button {
            dismiss()
          } label: {
            Text("Done", bundle: .module)
              .font(theme.fonts.body)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.primary)
          }

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Rectangle()
          .frame(height: 1)
          .foregroundStyle(theme.colors.border)

        List {
          VStack(spacing: 0) {
            ForEach(sessions) { session in
              if let user = session.user {
                AsyncButton {
                  await setActiveSession(session)
                } label: { isRunning in
                  HStack {
                    UserPreviewView(user: user)
                    Spacer()
                    if clerk.session?.id == session.id {
                      Image("icon-check", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(theme.colors.primary)
                    }
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.vertical, 16)
                  .padding(.horizontal, 24)
                  .frame(maxWidth: .infinity)
                  .contentShape(.rect)
                  .overlayProgressView(isActive: isRunning)
                }
                .overlay(alignment: .bottom) {
                  Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(theme.colors.border)
                }
                .buttonStyle(.pressedBackground)
                .disabled(clerk.session?.id == session.id)
              }
            }

            Button {
              authViewIsPresented = true
            } label: {
              UserButtonPopoverRow(icon: "icon-plus", text: "Add account")
            }
            .overlay(alignment: .bottom) {
              Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
            }
            .buttonStyle(.pressedBackground)

            AsyncButton {
              await signOutOfAllAccounts()
            } label: { isRunning in
              UserButtonPopoverRow(icon: "icon-sign-out", text: "Sign out of all accounts")
                .overlayProgressView(isActive: isRunning)
            }
            .overlay(alignment: .bottom) {
              Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.colors.border)
            }
            .buttonStyle(.pressedBackground)
          }
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)

        SecuredByClerkView()
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(theme.colors.backgroundSecondary)
      }
      .background(theme.colors.background)
      .sheet(isPresented: $authViewIsPresented) {
        AuthView()
      }
      .task {
        for await event in clerk.authEventEmitter.events {
          switch event {
          case .signInCompleted, .signUpCompleted:
            authViewIsPresented = false
          }
        }
      }
    }
  }

  #Preview {
    UserButtonAccountSwitcher()
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
