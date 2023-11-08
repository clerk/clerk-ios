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
        case primary
        case warning
    }
}

struct CapsuleTag: View {
    @Environment(\.clerkTheme) private var clerkTheme
    
    let text: String
    var style: Style = .primary
    
    private var foregroundStyle: Color {
        switch style {
        case .primary:
            return clerkTheme.colors.primaryButtonTextColor
        case .warning:
            return .red
        }
    }
    
    private var background: Color {
        switch style {
        case .primary:
            return clerkTheme.colors.primary.opacity(0.6)
        case .warning:
            return .red.opacity(0.1)
        }
    }
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(foregroundStyle)
            .background(background, in: Capsule())
    }
}

#Preview {
    Group {
        CapsuleTag(text: "Primary")
        CapsuleTag(text: "Unverfied", style: .warning)
    }
}

#endif
