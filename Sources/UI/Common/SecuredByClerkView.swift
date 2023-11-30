//
//  SecuredByClerkView.swift
//
//
//  Created by Mike Pitre on 11/29/23.
//

#if canImport(UIKit)

import SwiftUI

struct SecuredByClerkView: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Secured by ")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image("clerk-logomark", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                Text("clerk")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
    }
}

#Preview {
    SecuredByClerkView()
}

#endif
