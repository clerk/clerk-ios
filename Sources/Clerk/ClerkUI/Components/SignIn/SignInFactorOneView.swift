//
//  SignInFactorOneView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

import SwiftUI

struct SignInFactorOneView: View {
  @Environment(\.clerkTheme) private var theme
  
  var body: some View {
    ScrollView {
      Text("Hello World")
        .font(theme.fonts.title)
        .fontWeight(.bold)
        .multilineTextAlignment(.center)
        .frame(minHeight: 32)
        .padding(.bottom, 8)
        .foregroundStyle(theme.colors.text)
        .padding(.top, 64)
    }
  }
}

#Preview {
  SignInFactorOneView()
}
