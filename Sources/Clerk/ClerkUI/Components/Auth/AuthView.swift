//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

import Factory
import SwiftUI

public struct AuthView: View {
  @Environment(\.clerkTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @State var authState = AuthState()

  let showDismissButton: Bool

  public init(showDismissButton: Bool = true) {
    self.showDismissButton = showDismissButton
  }

  @ViewBuilder
  var dismissButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark.circle.fill")
        .resizable()
        .scaledToFit()
        .symbolRenderingMode(.palette)
        .foregroundStyle(theme.colors.textSecondary, .ultraThinMaterial)
        .frame(minWidth: 26, minHeight: 26)
    }
  }

  public var body: some View {
    NavigationStack(path: $authState.path) {
      SignInStartView()
        .toolbar {
          if showDismissButton {
            ToolbarItem(placement: .topBarTrailing) {
              dismissButton
            }
          }
        }
        .navigationDestination(for: AuthState.Destination.self) {
          $0.view
            .toolbar {
              if showDismissButton {
                ToolbarItem(placement: .topBarTrailing) {
                  dismissButton
                }
              }
            }
        }
    }
    .background(theme.colors.background)
    .tint(theme.colors.primary)
    .environment(\.authState, authState)
  }
}

#Preview("In sheet") {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      AuthView()
        .environment(\.clerk, .mock)
    }
}

#Preview("Not in sheet") {
  AuthView(showDismissButton: false)
    .environment(\.clerk, .mock)
}
