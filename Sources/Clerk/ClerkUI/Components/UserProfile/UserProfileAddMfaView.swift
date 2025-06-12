//
//  UserProfileAddMfaView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/3/25.
//

#if os(iOS)

  import SwiftUI

  struct UserProfileAddMfaView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var presentedView: PresentedView?
    @State private var error: Error?

    @Binding private var contentHeight: CGFloat

    enum PresentedView: Identifiable {
      case sms
      case authApp
      var id: Self { self }

      @ViewBuilder
      var view: some View {
        switch self {
        case .sms:
          UserProfileMfaAddSmsView()
        case .authApp:
          UserProfileMfaAddTotpView()
        }
      }
    }

    var extraContentHeight: CGFloat {
      if #available(iOS 26.0, *) {
        return 0
      } else {
        return 7
      }
    }

    var environment: Clerk.Environment { clerk.environment }
    var user: User? { clerk.user }

    init(
      contentHeight: Binding<CGFloat> = .constant(0)
    ) {
      self._contentHeight = contentHeight
    }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 24) {
            Text("Choose how you'd like to receive your two-step verification code.", bundle: .module)
              .font(theme.fonts.subheadline)
              .foregroundStyle(theme.colors.textSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 24)

            VStack(spacing: 0) {
              Group {
                if environment.mfaPhoneCodeIsEnabled {
                  Button {
                    presentedView = .sms
                  } label: {
                    UserProfileRowView(icon: "icon-phone", text: "SMS code")
                  }
                }

                if environment.mfaAuthenticatorAppIsEnabled, user?.totpEnabled != true {
                  Button {
                    presentedView = .authApp
                  } label: {
                    UserProfileRowView(icon: "icon-key", text: "Authenticator application")
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
          .background(theme.colors.background)
          .clerkErrorPresenting($error)
          .navigationBarTitleDisplayMode(.inline)
          .preGlassSolidNavBar()
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
                .foregroundStyle(theme.colors.text)
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
      .presentationBackground(theme.colors.background)
      .sheet(item: $presentedView) {
        $0.view
      }
    }
  }

  #Preview {
    UserProfileAddMfaView()
      .environment(\.clerk, .mock)
      .environment(\.clerkTheme, .clerk)
  }

#endif
