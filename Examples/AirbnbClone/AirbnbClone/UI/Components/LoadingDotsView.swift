//
//  LoadingDotsView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import SwiftUI

struct LoadingDotsView: View {
  var color: Color = .primary
  var dotSize: CGFloat = 6
  var spacing: CGFloat = 6
  var travel: CGFloat = 4

  @State private var animate = false

  var body: some View {
    HStack(spacing: spacing) {
      ForEach(0 ..< 3, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: dotSize, height: dotSize)
          .offset(y: animate ? -travel : 0)
          .animation(
            .easeInOut(duration: 0.6)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.15),
            value: animate
          )
      }
    }
    .onAppear { animate = true }
  }
}
