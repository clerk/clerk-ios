//
//  View+ErrorPresenting.swift
//
//
//  Created by Mike Pitre on 05/08/25.
//

#if os(iOS)

  import SwiftUI

  struct ClerkErrorViewModifier: ViewModifier {
    @Environment(\.clerkTheme) private var theme
    
    @Binding var error: Error?
    var action: ErrorView.ActionConfig?

    @State private var sheetHeight: CGFloat?

    var detents: Set<PresentationDetent> {
      if let sheetHeight {
        return [PresentationDetent.height(sheetHeight)]
      } else {
        return [.medium]
      }
    }

    func body(content: Content) -> some View {
      content
        .sheet(
          isPresented: Binding(
            get: { error != nil },
            set: { isPresented in
              if !isPresented {
                error = nil
              }
            }
          )
        ) {
          if let error {
            ErrorView(error: error, action: action)
              .padding()
              .onGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                  geometry.size.height
                },
                action: { newValue in
                  sheetHeight = newValue
                }
              )
              .presentationDetents(detents)
              .presentationDragIndicator(.visible)
              .presentationBackground(theme.colors.background)
          }
        }
    }
  }

  extension View {

    func clerkErrorPresenting(_ error: Binding<Error?>, action: ErrorView.ActionConfig? = nil) -> some View {
      modifier(ClerkErrorViewModifier(error: error, action: action))
    }

  }

  #Preview {
    @Previewable @State var error: Error?

    Button("Show Error") {
      error = ClerkClientError(message: "Password is incorrect. Try again, or use another method.")
    }
    .clerkErrorPresenting(
      $error,
      action: .init(
        text: "Call to action",
        action: {
          try! await Task.sleep(for: .seconds(1))
        }))
  }

#endif
