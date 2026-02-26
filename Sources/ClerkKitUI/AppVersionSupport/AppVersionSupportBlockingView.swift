//
//  AppVersionSupportBlockingView.swift
//  Clerk
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct AppVersionSupportBlockingView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.openURL) private var openURL
  @State private var isContentVisible = false
  @State private var entranceAnimationTask: Task<Void, Never>?

  let status: Clerk.AppVersionSupportStatus

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
      .opacity(isContentVisible ? 1 : 0)
      .offset(y: isContentVisible ? 0 : 12)
    }
    .onAppear {
      entranceAnimationTask?.cancel()
      isContentVisible = false
      entranceAnimationTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(90))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.22)) {
          isContentVisible = true
        }
      }
    }
    .onDisappear {
      entranceAnimationTask?.cancel()
      entranceAnimationTask = nil
      isContentVisible = false
    }
    .safeAreaInset(edge: .bottom) {
      bottomAction
        .opacity(isContentVisible ? 1 : 0)
        .offset(y: isContentVisible ? 0 : 12)
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

struct AppVersionSupportBlockingOverlayModifier: ViewModifier {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  private let controller = AppVersionSupportBlockingOverlayController.shared

  func body(content: Content) -> some View {
    ZStack {
      content
      if clerk.appVersionSupportStatus.isSupported == false {
        theme.colors.background
          .ignoresSafeArea()
          .allowsHitTesting(false)
          .zIndex(1)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onChange(of: clerk.appVersionSupportStatus, initial: true) { _, _ in
      syncOverlay()
    }
    .onDisappear {
      controller.clear()
    }
  }

  private func syncOverlay() {
    controller.update(with: clerk.appVersionSupportStatus, theme: theme, clerk: clerk)
  }
}

extension View {
  func clerkAppVersionSupportOverlay() -> some View {
    modifier(AppVersionSupportBlockingOverlayModifier())
  }
}

#Preview("With update link") {
  AppVersionSupportBlockingView(
    status: .init(
      isSupported: false,
      minimumVersion: "1.2.0",
      updateURL: URL(string: "https://apps.apple.com/app/id1234567890")
    )
  )
  .clerkPreview()
}

#Preview("Without update link") {
  AppVersionSupportBlockingView(
    status: .init(
      isSupported: false,
      minimumVersion: "1.2.0",
      updateURL: nil
    )
  )
  .clerkPreview()
}

#endif
