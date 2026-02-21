//
//  View+ErrorPresenting.swift
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct ClerkErrorViewModifier: ViewModifier {
  @Binding var error: Error?
  var onDismiss: ((Error?) -> Void)?
  var actionProvider: ((Error) -> ErrorView.ActionConfig?)?

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
        ),
        onDismiss: {
          onDismiss?(error)
        },
        content: {
          if let error {
            ErrorView(error: error, action: actionProvider?(error))
              .padding()
              .contentSizingDetent()
          }
        }
      )
  }
}

extension View {
  func clerkErrorPresenting(
    _ error: Binding<Error?>,
    onDismiss: ((Error?) -> Void)? = nil,
    action: ((Error) -> ErrorView.ActionConfig?)? = nil
  ) -> some View {
    modifier(ClerkErrorViewModifier(error: error, onDismiss: onDismiss, actionProvider: action))
  }
}

#Preview {
  @Previewable @State var error: Error?

  Button("Show Error") {
    error = ClerkClientError(message: "Password is incorrect. Try again, or use another method.")
  }
  .clerkErrorPresenting(
    $error,
    onDismiss: { _ in
      print("dismissed")
    },
    action: { _ in
      .init(
        text: "Call to action",
        action: {
          try? await Task.sleep(for: .seconds(1))
        }
      )
    }
  )
}

#endif
