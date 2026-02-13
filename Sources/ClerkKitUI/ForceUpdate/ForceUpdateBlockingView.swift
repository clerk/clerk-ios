//
//  ForceUpdateBlockingView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct ForceUpdateBlockingView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.openURL) private var openURL

  let status: Clerk.ForceUpdateStatus

  var body: some View {
    ZStack {
      theme.colors.background
        .ignoresSafeArea()

      VStack(spacing: 0) {
        VStack(spacing: 0) {
          AppLogoView()
            .frame(maxHeight: 44)
            .padding(.bottom, 24)

          VStack(spacing: 8) {
            HeaderView(style: .title, text: "Update required")
            HeaderView(style: .subtitle, text: "A newer version of this app is required to continue.")
          }
          .padding(.bottom, 32)

          HStack(alignment: .top, spacing: 12) {
            Image("icon-warning", bundle: .module)
              .resizable()
              .scaledToFit()
              .frame(width: 20, height: 20)
              .foregroundStyle(theme.colors.warning)
              .padding(10)
              .background(theme.colors.backgroundWarning, in: .circle)

            Text(message)
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.foreground)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(theme.colors.backgroundWarning)
          .clipShape(.rect(cornerRadius: theme.design.borderRadius))
          .overlay {
            RoundedRectangle(cornerRadius: theme.design.borderRadius)
              .strokeBorder(theme.colors.borderWarning, lineWidth: 1)
          }

          SecuredByClerkView()
            .padding(.top, 32)
        }
        .padding(16)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)

        Spacer(minLength: 0)
      }
    }
    .safeAreaInset(edge: .bottom) {
      bottomAction
    }
  }

  private var message: String {
    if let minimumVersion = status.minimumVersion, !minimumVersion.isEmpty {
      return "This version of the app is no longer supported. Please update to version \(minimumVersion) or newer."
    }

    return "This version of the app is no longer supported. Please update to continue."
  }

  @ViewBuilder
  private var bottomAction: some View {
    if let updateURL = status.updateURL {
      VStack(spacing: 0) {
        Rectangle()
          .fill(theme.colors.border)
          .frame(height: 1)

        Button {
          openURL(updateURL)
        } label: {
          Text("Update now")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary(config: .init(emphasis: .high, size: .large)))
        .padding(16)
      }
      .background(theme.colors.background)
    }
  }
}

struct ForceUpdateBlockingOverlayModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk
  @ObservedObject private var controller = ForceUpdateBlockingOverlayController.shared

  func body(content: Content) -> some View {
    content
      .task {
        controller.update(with: clerk.forceUpdateStatus)
      }
      .onChange(of: clerk.forceUpdateStatus) { _, newValue in
        controller.update(with: newValue)
      }
      .fullScreenCover(isPresented: isPresentedBinding) {
        if let status = controller.status {
          ForceUpdateBlockingView(status: status)
            .interactiveDismissDisabled(true)
        }
      }
  }

  private var isPresentedBinding: Binding<Bool> {
    Binding(
      get: { controller.status != nil },
      set: { _ in }
    )
  }
}

extension View {
  func clerkForceUpdateOverlay() -> some View {
    modifier(ForceUpdateBlockingOverlayModifier())
  }
}

#Preview("With update link") {
  ForceUpdateBlockingView(
    status: .init(
      isSupported: false,
      currentVersion: "1.0.0",
      minimumVersion: "1.2.0",
      updateURL: URL(string: "https://apps.apple.com/app/id1234567890"),
      reason: .belowMinimum
    )
  )
  .clerkPreview()
}

#Preview("Without update link") {
  ForceUpdateBlockingView(
    status: .init(
      isSupported: false,
      currentVersion: "1.0.0",
      minimumVersion: "1.2.0",
      updateURL: nil,
      reason: .serverRejected
    )
  )
  .clerkPreview()
}

#endif
