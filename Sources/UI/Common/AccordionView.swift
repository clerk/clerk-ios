//
//  AccordionView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if os(iOS)

import SwiftUI

struct AccordionView<Content: View, ExpandedContent: View>: View {
    @State private var isExpanded = false
    var horizontalSpacing: CGFloat? = nil
    @Environment(ClerkTheme.self) private var clerkTheme
    
    @ViewBuilder var content: Content
    @ViewBuilder var expandedContent: ExpandedContent
    
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                withAnimation(.snappy) {
                    isExpanded.toggle()
                }
            }, label: {
                HStack(spacing: .zero) {
                    content
                    Spacer(minLength: horizontalSpacing)
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                        .font(.system(size: 16).weight(.medium))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            })
            .buttonStyle(.plain)
            
            if isExpanded {
                expandedContent
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 30) {
            AccordionView {
                Text(verbatim: "ClerkUser@clerk.dev")
                    .fontWeight(.medium)
                    .frame(height: 20)
            } expandedContent: {
                VStack(alignment: .leading) {
                    Text("Primary email address").font(.subheadline.weight(.medium))
                    Text("This email address is the primary email address").font(.footnote)
                    Button("Remove email address", role: .destructive, action: {})
                        .font(.footnote)
                        .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Button {} label: {
                Text("+ Add an email address")
            }

        }
        .padding()
    }
}

#endif
