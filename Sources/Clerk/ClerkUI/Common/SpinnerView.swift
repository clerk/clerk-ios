//
//  SpinnerView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if os(iOS)

import SwiftUI

struct SpinnerView: View {
  @Environment(\.clerkTheme) private var theme
  @State private var rotation = 0.0
  
  var color: Color?
  
  var body: some View {
    Image("icon-spinner", bundle: .module)
      .resizable()
      .foregroundStyle(color ?? theme.colors.textSecondary)
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
  }
}

#Preview {
  SpinnerView()
    .frame(width: 24, height: 24)
  
  SpinnerView()
    .frame(width: 16, height: 16)
}

#endif
