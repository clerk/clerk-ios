//
//  ClerkFocusedBorder.swift
//  Clerk
//
//  Created by Mike Pitre on 4/18/25.
//

#if canImport(SwiftUI)

  import SwiftUI

  struct ClerkFocusedBorder: ViewModifier {
    @Environment(\.clerkTheme) private var theme

    enum BorderState {
      case `default`
      case error
    }
    
    var innerBorderColor: Color {
      switch state {
      case .default:
        isFocused ? theme.colors.inputBorderFocused : theme.colors.inputBorder
      case .error:
        theme.colors.dangerInputBorder
      }
    }

    var outerBorderColor: Color {
      switch state {
      case .default:
        theme.colors.inputBorder
      case .error:
        theme.colors.dangerInputBorderFocused
      }
    }

    let isFocused: Bool
    var state: BorderState = .default

    func body(content: Content) -> some View {
      content
        .animation(
          .default,
          body: { content in
            content
              .overlay {
                RoundedRectangle(cornerRadius: theme.design.borderRadius)
                  .strokeBorder(innerBorderColor,lineWidth: 1)
              }
              .background {
                RoundedRectangle(cornerRadius: theme.design.borderRadius)
                  .stroke(outerBorderColor, lineWidth: isFocused ? 4 : 0)
              }
          })
    }
  }

  extension View {
    func clerkFocusedBorder(isFocused: Bool = true, state: ClerkFocusedBorder.BorderState = .default) -> some View {
      modifier(ClerkFocusedBorder(isFocused: isFocused, state: state))
    }
  }

  #Preview {
    @Previewable @Environment(\.clerkTheme) var theme

    VStack(spacing: 20) {
      
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .fill(theme.colors.background)
        .frame(maxWidth: .infinity, maxHeight: 48)
        .clerkFocusedBorder(isFocused: false)

      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .fill(theme.colors.background)
        .frame(maxWidth: .infinity, maxHeight: 48)
        .clerkFocusedBorder()
      
      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .fill(theme.colors.background)
        .frame(maxWidth: .infinity, maxHeight: 48)
        .clerkFocusedBorder(isFocused: false, state: .error)

      RoundedRectangle(cornerRadius: theme.design.borderRadius)
        .fill(theme.colors.background)
        .frame(maxWidth: .infinity, maxHeight: 48)
        .clerkFocusedBorder(state: .error)

    }
    .padding()
  }

#endif
