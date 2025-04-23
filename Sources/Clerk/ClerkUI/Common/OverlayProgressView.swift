//
//  SwiftUIView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if canImport(SwiftUI)

import SwiftUI

struct OverlayProgressModifier<ProgressView: View>: ViewModifier {
  let isActive: Bool
  let progressView: () -> ProgressView

  func body(content: Content) -> some View {
    content
      .opacity(isActive ? 0 : 1)
      .overlay {
        if isActive {
          progressView()
        }
      }
  }
}

extension View {
  func overlayProgressView<ProgressView: View>(
    isActive: Bool,
    progressView: @escaping () -> ProgressView = { SpinnerView() }
  ) -> some View {
    modifier(OverlayProgressModifier(isActive: isActive, progressView: progressView))
  }
}

#Preview {
  AsyncButton {
    try! await Task.sleep(for: .seconds(3))
  } label: { isRunning in
    Text("Button")
      .overlayProgressView(isActive: isRunning)
  }
  .buttonStyle(.primary())
  .padding()
}

#endif
