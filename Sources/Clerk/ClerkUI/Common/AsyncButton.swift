//
//  AsyncButton.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

import SwiftUI

struct AsyncButton<ProgressView: View, Label: View>: View {
  @Environment(\.clerkTheme) private var theme
  @State private var isRunning = false

  let action: () async -> Void
  @ViewBuilder let progressView: ProgressView
  @ViewBuilder let label: Label

  var body: some View {
    Button {
      Task {
        isRunning = true
        defer { isRunning = false }
        await action()
      }
    } label: {
      label
        .opacity(isRunning ? 0 : 1)
        .overlay {
          if isRunning {
            progressView
          }
        }
    }
    .disabled(isRunning)
    .animation(.default, value: isRunning)
  }
}

extension AsyncButton where ProgressView == SpinnerView {
  init(
    action: @escaping () async -> Void,
    @ViewBuilder label: @escaping () -> Label
  ) {
    self.init(
      action: action,
      progressView: {
        SpinnerView()
      },
      label: label
    )
  }
}

#Preview {
  AsyncButton {
    do {
      try await Task.sleep(for: .seconds(2))
    } catch {
      dump(error)
    }
  } label: {
    Text("Button")
  }
  .buttonStyle(.primary)
  .padding()
  
  AsyncButton {
    do {
      try await Task.sleep(for: .seconds(2))
    } catch {
      dump(error)
    }
  }
  progressView: {
    SpinnerView(color: .secondary)
  }
  label: {
    Text("Button")
  }
  .padding()
}
