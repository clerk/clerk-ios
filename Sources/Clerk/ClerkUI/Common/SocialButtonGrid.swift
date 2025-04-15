//
//  SocialButtonGrid.swift
//  Clerk
//
//  Created by Mike Pitre on 4/11/25.
//

import Algorithms
import Clerk
import SwiftUI

struct SocialButtonGrid: View {
  let providers: [OAuthProvider]

  @State private var height: CGFloat?
  private let itemWidth: CGFloat = 112
  private let spacing: CGFloat = 8

  func maxFittingItemCount(containerWidth: CGFloat) -> Int {
    guard containerWidth >= itemWidth else { return 0 }
    let count = (containerWidth + spacing) / (itemWidth + spacing)
    return Int(floor(count))
  }

  func chunkedProviders(containerWidth: CGFloat) -> ChunksOfCountCollection<[OAuthProvider]> {
    guard maxFittingItemCount(containerWidth: containerWidth) > 0 else {
      return providers.chunks(ofCount: 1)
    }

    return providers.chunks(ofCount: maxFittingItemCount(containerWidth: containerWidth))
  }

  var body: some View {
    GeometryReader { geometry in
      Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
        ForEach(chunkedProviders(containerWidth: geometry.size.width), id: \.self) { chunk in
          GridRow {
            ForEach(chunk) { provider in
              SocialButton(provider: provider)
            }
          }
        }
      }
      .onGeometryChange(for: CGFloat.self) { geometry in
        geometry.size.height
      } action: { newValue in
        height = newValue
      }
    }
    .frame(height: height)
  }
}

#Preview {
  VStack(spacing: 50) {
    SocialButtonGrid(providers: [.google])
    SocialButtonGrid(providers: [.google, .apple])
    SocialButtonGrid(providers: [.google, .apple, .facebook, .github])
  }
  .frame(maxWidth: .infinity)
  .padding()
}
