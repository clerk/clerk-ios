//
//  UserPreviewView.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if os(iOS)

import SwiftUI
import Clerk
import Kingfisher

struct UserPreviewView: View {
    @Environment(ClerkTheme.self) private var clerkTheme
    
    var title: String?
    var subtitle: String?
    var imageUrl: String?
    
    var body: some View {
        HStack(spacing: 16) {
            if let imageUrl {
                KFImage(URL(string: imageUrl))
                    .resizable()
                    .placeholder { Color(.secondarySystemBackground) }
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(.circle)
            }
            
            VStack(alignment: .leading) {
                if let title {
                    Text(title)
                        .font(.footnote.weight(.medium))
                }
                
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                }
            }
        }
    }
}

extension UserPreviewView {
    init(
        user: User,
        hideTitle: Bool = false,
        hideSubtitle: Bool = false
    ) {
        self.title = hideTitle ? nil : user.fullName
        self.subtitle = hideSubtitle ? nil : user.identifier
        self.imageUrl = user.imageUrl
    }
}

#Preview {
    VStack(spacing: 20) {
        UserPreviewView(user: Clerk.shared.user!)
        UserPreviewView(title: nil, subtitle: "clerkuser@clerk.dev", imageUrl: "")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
}

#endif
