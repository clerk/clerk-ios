//
//  SocialButtonGrid.swift
//  Clerk
//
//  Created by Mike Pitre on 4/11/25.
//

import Clerk
import SwiftUI

struct SocialButtonGrid: View {
  let providers: [OAuthProvider]

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
    GridItem(.flexible())
  ]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 8) {
      ForEach(providers) { provider in
        SocialButton(provider: provider)
      }
    }
  }
}

#Preview {
  SocialButtonGrid(providers: [.google, .apple, .slack])
    .padding()
}
