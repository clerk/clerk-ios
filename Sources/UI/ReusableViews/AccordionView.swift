//
//  AccordionView.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI

struct AccordionView<Content: View, ExpandedContent: View>: View {
    @State private var isExpanded = false
    
    @ViewBuilder var content: Content
    @ViewBuilder var expandedContent: ExpandedContent
    
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                withAnimation(.bouncy) {
                    isExpanded.toggle()
                }
            }, label: {
                HStack {
                    content
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
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
