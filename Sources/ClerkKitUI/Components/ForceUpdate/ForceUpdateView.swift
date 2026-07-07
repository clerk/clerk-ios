//
//  ForceUpdateView.swift
//

#if os(iOS) || os(macOS)

  import ClerkKit
  import SwiftUI

  public struct ForceUpdateView: View {
    @Environment(Clerk.self) private var clerk

    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey

    public init(
      title: LocalizedStringKey = "Update required",
      subtitle: LocalizedStringKey = "A newer version of this app is required to continue."
    ) {
      self.title = title
      self.subtitle = subtitle
    }

    public var body: some View {
      if let forceUpdate = clerk.environment?.forceUpdate,
        forceUpdate.required,
        let appStoreURL = forceUpdate.validAppStoreURL
      {
        ForceUpdateContentView(
          appStoreURL: appStoreURL,
          title: title,
          subtitle: subtitle
        )
      }
    }
  }

  private struct ForceUpdateContentView: View {
    @Environment(\.clerkTheme) private var theme
    @Environment(\.openURL) private var openURL

    let appStoreURL: URL
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
      VStack(spacing: 24) {
        AppLogoView()

        VStack(spacing: 8) {
          HeaderView(style: .title, text: title)
          HeaderView(style: .subtitle, text: subtitle)
        }

        Button {
          openURL(appStoreURL)
        } label: {
          Label("Update app", systemImage: "arrow.down.circle")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary(config: .init(emphasis: .high, size: .large)))
      }
      .padding()
      .frame(maxWidth: 360)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(theme.colors.background)
    }
  }

  #Preview {
    ForceUpdateContentView(
      appStoreURL: URL(string: "https://apps.apple.com/app/id123456789")!,
      title: "Update required",
      subtitle: "A newer version of this app is required to continue."
    )
  }

  extension Clerk.Environment.ForceUpdate {
    fileprivate var validAppStoreURL: URL? {
      guard
        let appStoreURL,
        let scheme = appStoreURL.scheme,
        ["http", "https"].contains(scheme),
        appStoreURL.host != nil
      else {
        return nil
      }

      return appStoreURL
    }
  }

#endif
