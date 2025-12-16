//
//  AuthOptionButton.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct AuthOptionButton: View {
  var icon: String?
  var iconURL: URL?
  var provider: OAuthProvider?
  var isLoading: Bool = false
  let title: String
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  private var resolvedIconURL: URL? {
    if let iconURL {
      return iconURL
    }
    if let provider {
      return provider.iconImageUrl(darkMode: colorScheme == .dark)
    }
    return nil
  }

  var body: some View {
    Button(action: action) {
      ZStack {
        Text(title)
          .font(.system(size: 16, weight: .medium))
          .opacity(isLoading ? 0 : 1)

        HStack {
          Group {
            if let icon {
              Image(systemName: icon)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 18))
                .frame(width: 20, height: 20)
            } else if let url = resolvedIconURL {
              AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                case .failure:
                  Image(systemName: "questionmark.circle")
                    .font(.system(size: 18))
                case .empty:
                  ProgressView()
                    .scaleEffect(0.7)
                @unknown default:
                  EmptyView()
                }
              }
              .frame(width: 20, height: 20)
            }
          }
          Spacer()
        }
        .opacity(isLoading ? 0 : 1)
      }
      .overlay {
        if isLoading {
          LoadingDotsView()
            .frame(maxWidth: .infinity)
        }
      }
      .foregroundStyle(Color(uiColor: .label))
      .padding(.horizontal, 16)
      .frame(height: 46)
      .background {
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(Color(uiColor: .systemGray3), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  VStack(spacing: 16) {
    AuthOptionButton(icon: "envelope", title: "Continue with email") {}
    AuthOptionButton(icon: "apple.logo", title: "Continue with Apple") {}
    AuthOptionButton(provider: .google, title: "Continue with Google") {}
    AuthOptionButton(provider: .facebook, title: "Continue with Facebook") {}
  }
  .padding()
  .environment(Clerk.preview())
}
