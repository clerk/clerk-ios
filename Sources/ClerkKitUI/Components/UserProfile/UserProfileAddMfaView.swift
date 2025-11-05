//
//  UserProfileAddMfaView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/3/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct UserProfileAddMfaView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(UserProfileView.SharedState.self) private var sharedState
  @Environment(\.dismiss) private var dismiss

  @State private var error: Error?

  @Binding private var contentHeight: CGFloat

  enum PresentedView: Identifiable, Hashable {
    case sms
    case authApp(TOTPResource)
    var id: Self { self }

    @MainActor
    @ViewBuilder
    var view: some View {
      switch self {
      case .sms:
        UserProfileMfaAddSmsView()
      case let .authApp(totp):
        UserProfileMfaAddTotpView(totp: totp)
      }
    }
  }

  var extraContentHeight: CGFloat {
    if #available(iOS 26.0, *) {
      0
    } else {
      7
    }
  }

  var environment: Clerk.Environment { clerk.environment }
  var user: User? { clerk.user }

  init(
    contentHeight: Binding<CGFloat> = .constant(0)
  ) {
    _contentHeight = contentHeight
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          Text("Choose how you'd like to receive your two-step verification code.", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)

          VStack(spacing: 0) {
            Group {
              if environment.mfaPhoneCodeIsEnabled {
                Button {
                  sharedState.chooseMfaTypeIsPresented = false
                  sharedState.presentedAddMfaType = .sms
                } label: {
                  UserProfileRowView(icon: "icon-phone", text: "SMS code")
                }
              }

              if environment.mfaAuthenticatorAppIsEnabled, user?.totpEnabled != true {
                AsyncButton {
                  await createTotp()
                } label: { isRunning in
                  UserProfileRowView(icon: "icon-key", text: "Authenticator application")
                    .overlayProgressView(isActive: isRunning)
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
        }
        .padding(.top, 24)
        .clerkErrorPresenting($error)
        .navigationBarTitleDisplayMode(.inline)
        .preGlassSolidNavBar()
        .preGlassDetentSheetBackground()
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              dismiss()
            }
            .foregroundStyle(theme.colors.primary)
          }

          ToolbarItem(placement: .principal) {
            Text("Add two-step verification", bundle: .module)
              .font(theme.fonts.headline)
              .foregroundStyle(theme.colors.foreground)
          }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
          proxy.size.height
        } action: { newValue in
          contentHeight = newValue + UITabBarController().tabBar.frame.size.height + extraContentHeight
        }
      }
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}

extension UserProfileAddMfaView {
  private func createTotp() async {
    guard let user else { return }

    do {
      let totp = try await user.createTOTP()
      sharedState.chooseMfaTypeIsPresented = false
      sharedState.presentedAddMfaType = .authApp(totp)
    } catch {
      self.error = error
      ClerkLogger.error("Failed to create TOTP", error: error)
    }
  }
}

#Preview {
  UserProfileAddMfaView()
    .clerkPreviewMocks()
    .environment(\.clerkTheme, .clerk)
}

#endif
