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

  func maxFittingItemCount(
    containerWidth: CGFloat,
    itemWidth: CGFloat = 112,
    spacing: CGFloat = 8
  ) -> Int {
    guard containerWidth >= itemWidth else { return 0 }
    let count = (containerWidth + spacing) / (itemWidth + spacing)
    return Int(floor(count)) 
  }

  private func columns(containerWidth: CGFloat) -> [GridItem] {
    let maxFittingItems = maxFittingItemCount(containerWidth: containerWidth)
    
    return Array(
      repeating: GridItem(.flexible()),
      count: maxFittingItems >= providers.count ? providers.count : maxFittingItems
    )
  }

  var body: some View {
    GeometryReader { geometry in
      LazyVGrid(
        columns: columns(containerWidth: geometry.size.width),
        spacing: 8
      ) {
        ForEach(providers) { provider in
          SocialButton(provider: provider)
        }
      }
    }
  }
}

#Preview {
  VStack {
    SocialButtonGrid(providers: [.google])
    SocialButtonGrid(providers: [.google, .apple])
    SocialButtonGrid(providers: [.google, .apple, .facebook, .github])
  }
  .frame(maxWidth: .infinity)
  .padding()
}
