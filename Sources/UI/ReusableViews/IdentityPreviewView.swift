//
//  IdentityPreviewView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI

struct IdentityPreviewView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    var imageUrl: String?
    var label: String
    var action: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .center) {
            if let imageUrl {
                AsyncImage(url: URL(string: imageUrl), transaction: Transaction(animation: .default)) { phase in
                    switch phase {
                    case .empty:
                        clerkTheme.colors.primary
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        clerkTheme.colors.primary
                    @unknown default:
                        clerkTheme.colors.primary
                    }
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
            }
            
            Text(label)
                .font(.footnote.weight(.light))
            
            if let action {
                Button(action: {
                    action()
                }, label: {
                    Image(systemName: "square.and.pencil")
                        .bold()
                        .foregroundStyle(clerkTheme.colors.primary)
                })
            }
        }
        .padding(10)
        .padding(.horizontal, 6)
        .overlay {
            Capsule()
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}

struct IdentityPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        IdentityPreviewView(
            imageUrl: "",
            label: "clerkuser@gmail.com",
            action: {}
        )
    }
}

#endif