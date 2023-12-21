//
//  OrgLogoView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

import SwiftUI

struct OrgLogoView: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    var body: some View {
        Image(systemName: "circle.square.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 32, height: 32)
            .foregroundStyle(clerkTheme.colors.gray700)
    }
}

#Preview {
    OrgLogoView()
}
