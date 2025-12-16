//
//  WelcomeView.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import SwiftUI

struct WelcomeView: View {
  @Binding var showLoginSheet: Bool

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 0) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Profile")
            .font(.system(size: 34, weight: .bold))

          Text("Log in and start planning your next trip.")
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)

        Button {
          showLoginSheet = true
        } label: {
          Text("Log in or sign up")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(uiColor: .label))
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)

        Spacer()
      }
    }
  }
}

struct MenuRow: View {
  let icon: String
  let title: String

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 20))
        .foregroundStyle(.primary)
        .frame(width: 28)

      Text(title)
        .font(.system(size: 16))

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }
}

#Preview {
  WelcomeView(showLoginSheet: .constant(false))
}
