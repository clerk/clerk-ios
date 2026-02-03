//
//  SetupMfaStartView.swift
//  Clerk
//
//  Created by Clerk on 1/28/26.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct SetupMfaStartView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation

  @State private var error: Error?

  var session: Session? {
    clerk.client?.sessions.first { $0.status == .pending && $0.currentTask != nil }
  }

  var user: User? {
    session?.user
  }

  var clerkEnvironment: Clerk.Environment? {
    clerk.environment
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        HeaderView(style: .title, text: "Set up two-step verification")
          .padding(.bottom, 8)

        HeaderView(style: .subtitle, text: "Choose how you'd like to receive your two-step verification code")
          .padding(.bottom, 32)

        VStack(spacing: 0) {
          Group {
            if clerkEnvironment?.mfaPhoneCodeIsEnabled == true {
              Button {
                navigation.path.append(AuthView.Destination.setupMfaPhone)
              } label: {
                MfaMethodRow(icon: "icon-phone", text: "SMS code")
              }
            }

            if clerkEnvironment?.mfaAuthenticatorAppIsEnabled == true {
              AsyncButton {
                await createTotp()
              } label: { isRunning in
                MfaMethodRow(icon: "icon-key", text: "Authenticator application")
                  .overlayProgressView(isActive: isRunning) {
                    SpinnerView(color: theme.colors.foreground)
                  }
              }
            }
          }
          .overlay(alignment: .bottom) {
            Rectangle()
              .frame(height: 1)
              .foregroundStyle(theme.colors.border)
          }
          .buttonStyle(.pressedBackground)
          .simultaneousGesture(TapGesture())
        }
        .overlay(alignment: .top) {
          Rectangle()
            .frame(height: 1)
            .foregroundStyle(theme.colors.border)
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .clerkErrorPresenting($error)
    .navigationBarBackButtonHidden()
  }
}

extension SetupMfaStartView {
  func createTotp() async {
    guard let user else { return }

    do {
      let totp = try await user.createTOTP()
      navigation.path.append(AuthView.Destination.setupMfaTotp(totp))
    } catch {
      self.error = error
    }
  }
}

struct MfaMethodRow: View {
  @Environment(\.clerkTheme) private var theme

  let icon: String
  let text: LocalizedStringKey

  var body: some View {
    HStack(spacing: 16) {
      Image(icon, bundle: .module)
        .resizable()
        .scaledToFit()
        .frame(width: 48, height: 24)
        .foregroundStyle(theme.colors.mutedForeground)
      Text(text, bundle: .module)
        .font(theme.fonts.body)
        .fontWeight(.semibold)
        .foregroundStyle(theme.colors.foreground)
        .frame(minHeight: 22)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 16)
    .padding(.horizontal, 24)
    .contentShape(.rect)
  }
}

#Preview {
  SetupMfaStartView()
    .environment(\.clerkTheme, .clerk)
}

#endif
