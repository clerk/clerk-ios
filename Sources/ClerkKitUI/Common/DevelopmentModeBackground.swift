//
//  DevelopmentModeBackground.swift
//  Clerk
//

#if os(iOS)

import SwiftUI

enum DevelopmentModeBackground {
  case white
  case gray

  var imageName: String {
    switch self {
    case .white:
      "dev-mode-background-white"
    case .gray:
      "dev-mode-background-gray"
    }
  }
}

struct DevelopmentModeBackgroundView: View {
  let background: DevelopmentModeBackground

  var body: some View {
    GeometryReader { proxy in
      Image(background.imageName, bundle: .module)
        .resizable()
        .scaledToFill()
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

#endif
