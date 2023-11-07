//
//  UserProfileSectionHeader.swift
//
//
//  Created by Mike Pitre on 11/3/23.
//

#if canImport(UIKit)

import SwiftUI

struct UserProfileSectionHeader: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.body.weight(.semibold))
            Divider()
        }
    }
}

#Preview {
    UserProfileSectionHeader(title: "Profile")
        .padding()
}

#endif
