//
//  SpinnerView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct SpinnerView: View {
  @Environment(\.clerkTheme) private var theme
  @State private var rotation = 0.0
  
  var color: Color?
  
  var body: some View {
    Image("spinner", bundle: .module)
      .resizable()
      .foregroundStyle(color ?? theme.colors.textSecondary)
      .frame(width: 24, height: 24)
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
      .onDisappear {
        rotation = 0
      }
  }
}

#Preview {
  SpinnerView()
  SpinnerView(color: .secondary)
}

#endif
