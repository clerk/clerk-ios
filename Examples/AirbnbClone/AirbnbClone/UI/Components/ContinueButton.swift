//
//  ContinueButton.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/16/25.
//

import SwiftUI

/// Primary continue button with loading state.
struct ContinueButton: View {
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("Continue")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .opacity(isLoading ? 0 : 1)
        .overlay {
          if isLoading {
            LoadingDotsView(color: .white)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color(red: 0.87, green: 0.0, blue: 0.35))
        .clipShape(.rect(cornerRadius: 10))
    }
    .disabled(isLoading)
  }
}
