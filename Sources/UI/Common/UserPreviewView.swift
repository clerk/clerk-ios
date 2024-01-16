//
//  UserPreviewView.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if canImport(UIKit)

import SwiftUI
import NukeUI
import Clerk
import Nuke

struct UserPreviewView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    var title: String?
    var subtitle: String?
    var imageUrl: String?
    
    var body: some View {
        HStack(spacing: 16) {
            if let imageUrl {
                LazyImage(
                    request: .init(url: URL(string: imageUrl), processors: [ImageProcessors.Circle()]),
                    transaction: .init(animation: .default)
                ) { imageState in
                    if let image = imageState.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
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

extension UserPreviewView {
    init(
        session: Session,
        hideTitle: Bool = false,
        hideSubtitle: Bool = false
    ) {
        self.title = hideTitle ? nil : session.user?.fullName
        self.subtitle = hideSubtitle ? nil : session.identifier
        self.imageUrl = session.user?.imageUrl
    }
}

#Preview {
    VStack(spacing: 20) {
        UserPreviewView(user: .mock)
        UserPreviewView(title: nil, subtitle: "clerkuser@clerk.dev", imageUrl: "")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
}

#endif
