//
//  DevelopmentModeBackgroundView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import SwiftUI

struct DevelopmentModeBackgroundView: View {
  let background: DevelopmentModeBackground

  var body: some View {
    Rectangle()
      .fill(.clear)
      .overlay {
        Image(background.imageName, bundle: .module)
          .resizable()
          .scaledToFill()
      }
      .clipped()
  }
}

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

#endif
