//
//  SpinnerView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct SpinnerView: View {
  @Environment(\.clerkTheme) private var theme
  @State private var rotation = 0.0

  var color: Color?

  var body: some View {
    #if os(iOS)
    ClerkRepeatingAnimation(kind: .spinner, color: color ?? theme.colors.mutedForeground)
    #else
    Image("icon-spinner", bundle: .module)
      .resizable()
      .foregroundStyle(color ?? theme.colors.mutedForeground)
      .scaledToFit()
      .rotationEffect(.degrees(rotation))
      .onAppear {
        withAnimation(
          .linear(duration: 1.0)
            .repeatForever(autoreverses: false)
        ) {
          rotation = 360
        }
      }
    #endif
  }
}

#Preview {
  SpinnerView()
    .frame(width: 24, height: 24)

  SpinnerView()
    .frame(width: 16, height: 16)
}

#endif
