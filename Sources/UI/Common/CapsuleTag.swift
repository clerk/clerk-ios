//
//  Capsules.swift
//
//
//  Created by Mike Pitre on 11/8/23.
//

#if canImport(UIKit)

import SwiftUI

extension CapsuleTag {
    enum Style {
        case regular
        case warning
    }
}

struct CapsuleTag: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    let text: String
    var style: Style = .regular
    
    private var foregroundStyle: Color {
        switch style {
        case .regular:
            return (clerkTheme.colors.textSecondary)
        case .warning:
            return .red
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .frame(minHeight: 18)
            .foregroundStyle(foregroundStyle)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 4))
            .shadow(radius: 0.5)
    }
}

#Preview {
    Group {
        CapsuleTag(text: "Primary")
        CapsuleTag(text: "Unverfied", style: .warning)
    }
}

#endif
