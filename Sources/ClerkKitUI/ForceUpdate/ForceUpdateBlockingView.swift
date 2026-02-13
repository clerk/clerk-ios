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
      theme.colors.muted
        .ignoresSafeArea()

      VStack(spacing: 20) {
        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
          .font(.system(size: 56))
          .foregroundStyle(theme.colors.primary)

        Text("Update required")
          .font(theme.fonts.title)
          .fontWeight(.semibold)
          .foregroundStyle(theme.colors.foreground)
          .multilineTextAlignment(.center)

        Text(message)
          .font(theme.fonts.body)
          .foregroundStyle(theme.colors.mutedForeground)
          .multilineTextAlignment(.center)
      }
      .padding(24)
      .frame(maxWidth: 420)
      .background(theme.colors.background)
      .clipShape(RoundedRectangle(cornerRadius: theme.design.borderRadius))
      .overlay(
        RoundedRectangle(cornerRadius: theme.design.borderRadius)
          .strokeBorder(theme.colors.border, lineWidth: 1)
      )
      .padding(24)
      .safeAreaInset(edge: .bottom) {
        if let updateURL = status.updateURL {
          Button {
            openURL(updateURL)
          } label: {
            Text("Update now")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.primary(config: .init(emphasis: .high, size: .large)))
          .padding(24)
          .background(theme.colors.muted)
        }
      }
    }
  }

  private var message: String {
    if let minimumVersion = status.minimumVersion, !minimumVersion.isEmpty {
      return "This version of the app is no longer supported. Please update to version \(minimumVersion) or newer."
    }

    return "This version of the app is no longer supported. Please update to continue."
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

#endif
