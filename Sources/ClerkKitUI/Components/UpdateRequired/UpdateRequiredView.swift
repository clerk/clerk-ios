//
//  UpdateRequiredView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

/// A full-screen view telling the user to update the app because its version is older than the
/// minimum set in the Clerk Dashboard.
///
/// Clerk presents this view over your app automatically, with the theme and app icon you set
/// with ``SwiftUICore/View/clerkTheme(_:)`` and ``SwiftUICore/View/clerkAppIcon(_:)``. Place it
/// yourself only after setting ``Clerk/Options/updateRequiredViewEnabled`` to `false`, for example:
///
/// ```swift
/// ContentView()
///   .fullScreenCover(isPresented: .constant(!clerk.appVersionSupportStatus.isSupported)) {
///     UpdateRequiredView()
///   }
/// ```
public struct UpdateRequiredView: View {
  @Environment(Clerk.self) private var clerk

  public init() {}

  public var body: some View {
    UpdateRequiredContentView(
      status: clerk.appVersionSupportStatus,
      appName: clerk.environment?.displayConfig.applicationName,
      supportEmail: clerk.environment?.displayConfig.supportEmail
    )
  }
}

struct UpdateRequiredContentView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.openURL) private var openURL

  let status: Clerk.AppVersionSupportStatus
  let appName: String?
  let supportEmail: String?

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Update required")
          HeaderView(
            style: .subtitle,
            text: "This version of \(displayedAppName) is no longer supported. To keep your account secure, please update to continue."
          )
        }
        .padding(.bottom, 24)

        if let minimumVersion = status.minimumVersion {
          versionComparison(minimumVersion: minimumVersion)
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 60)
    }
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      actions
    }
    .background(theme.colors.background.ignoresSafeArea())
  }

  private var displayedAppName: String {
    if let appName, !appName.isEmpty {
      return appName
    }
    return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? ""
  }

  private func versionComparison(minimumVersion: String) -> some View {
    HStack(spacing: 0) {
      versionColumn(title: "Your version", version: status.currentVersion)

      Rectangle()
        .fill(theme.colors.border)
        .frame(width: 1)
        .padding(.vertical, 1)

      versionColumn(title: "Required", version: "\(minimumVersion)+")
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(theme.colors.neutral.opacity(0.03))
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(theme.colors.border, lineWidth: 1)
    }
  }

  private func versionColumn(title: LocalizedStringKey, version: String) -> some View {
    VStack(spacing: 2) {
      Text(title, bundle: .module)
        .font(theme.fonts.callout)
        .foregroundStyle(theme.colors.mutedForeground)
      Text(verbatim: version)
        .font(theme.fonts.headline)
        .fontWeight(.semibold)
        .foregroundStyle(theme.colors.foreground)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }

  private var actions: some View {
    VStack(spacing: 12) {
      if let updateURL = status.updateURL {
        Button {
          openURL(updateURL)
        } label: {
          Text("Go to App Store", bundle: .module)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary(config: .init(emphasis: .high, size: .large)))
        .simultaneousGesture(TapGesture())
      }

      if let supportURL {
        Button {
          openURL(supportURL)
        } label: {
          HStack(spacing: 4) {
            Text("Can't update?", bundle: .module)
              .foregroundStyle(theme.colors.mutedForeground)
            Text("Get Help", bundle: .module)
              .fontWeight(.semibold)
              .foregroundStyle(theme.colors.primary)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondary(config: .init(emphasis: .none, size: .small)))
        .simultaneousGesture(TapGesture())
      }
    }
    .frame(maxWidth: 320)
    .padding(.horizontal, 24)
    .padding(.top, 16)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity)
    .background(theme.colors.background)
  }

  private var supportURL: URL? {
    guard let supportEmail, !supportEmail.isEmpty else { return nil }
    return URL(string: "mailto:\(supportEmail)")
  }
}

#Preview("Update required") {
  UpdateRequiredContentView(
    status: .init(
      isSupported: false,
      currentVersion: "4.8.4",
      minimumVersion: "5.0",
      updateURL: URL(string: "https://apps.apple.com/app/id123456789")
    ),
    appName: "Acme",
    supportEmail: "support@example.com"
  )
  .clerkPreview()
}

#Preview("Without store link or support email") {
  UpdateRequiredContentView(
    status: .init(isSupported: false, currentVersion: "4.8.4", minimumVersion: nil, updateURL: nil),
    appName: "Acme",
    supportEmail: nil
  )
  .clerkPreview()
}

#endif
