//
//  ErrorMessage.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/16/25.
//

import SwiftUI

/// Displays an error message with an icon.
struct ErrorMessage: View {
  let message: String?

  var body: some View {
    if let message {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 14))
        Text(message)
          .font(.system(size: 14))
      }
      .foregroundStyle(Color(red: 0.76, green: 0.15, blue: 0.18))
      .frame(maxWidth: .infinity, alignment: .leading)
      .transition(.opacity)
    }
  }
}
