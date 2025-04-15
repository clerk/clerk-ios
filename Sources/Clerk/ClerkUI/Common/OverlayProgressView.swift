//
//  SwiftUIView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

import SwiftUI

extension View {
  @ViewBuilder
  func overlayProgressView<ProgressView: View>(
    isActive: Bool,
    progressView: @escaping () -> ProgressView = { SpinnerView() }
  ) -> some View {
    self
      .opacity(isActive ? 0 : 1)
      .overlay {
        if isActive {
          progressView()
        }
      }
  }
}

#Preview {
  AsyncButton {
    try! await Task.sleep(for: .seconds(3))
  } label: { isRunning in
    Text("Button")
      .overlayProgressView(isActive: isRunning)
  }
  .buttonStyle(.primary)
  .padding()
}
