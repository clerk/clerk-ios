//
//  SocialButton.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

struct SocialButton: View {
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
        // Reserve height so the button doesn't shrink when we swap content for a loader.
        Text(title)
          .font(.system(size: 16, weight: .medium))
          .opacity(isLoading ? 0 : 1)

        // Left-aligned icon (hidden while loading)
        HStack {
          Group {
            if let icon {
              Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 24, height: 24)
            } else if let url = resolvedIconURL {
              AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                case .failure:
                  Image(systemName: "questionmark.circle")
                    .font(.system(size: 20))
                case .empty:
                  ProgressView()
                    .scaleEffect(0.7)
                @unknown default:
                  EmptyView()
                }
              }
              .frame(width: 24, height: 24)
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
      .foregroundStyle(.primary)
      .padding(.horizontal, 16)
      .frame(height: 56)
      .background {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(Color(uiColor: .systemGray3), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  VStack(spacing: 16) {
    SocialButton(icon: "envelope", title: "Continue with email") {}
    SocialButton(icon: "apple.logo", title: "Continue with Apple") {}
    SocialButton(provider: .google, title: "Continue with Google") {}
    SocialButton(provider: .facebook, title: "Continue with Facebook") {}
  }
  .padding()
  .environment(Clerk.preview())
}
