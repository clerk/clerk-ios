//
//  CloseButton.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/16/25.
//

import SwiftUI

/// Standard close button.
struct CloseButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(uiColor: .label))
    }
    .buttonStyle(.plain)
  }
}
