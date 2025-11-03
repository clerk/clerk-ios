//
//  AsyncButton.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

#if os(iOS)

import SwiftUI

struct AsyncButton<Label: View>: View {
  @State private var isRunning = false

  let role: ButtonRole?
  let action: () async -> Void
  let label: (_ isRunning: Bool) -> Label

  var onIsRunningChanged: ((Bool) -> Void)?

  init(
    role: ButtonRole? = nil,
    action: @escaping () async -> Void,
    @ViewBuilder label: @escaping (_ isRunning: Bool) -> Label
  ) {
    self.role = role
    self.action = action
    self.label = label
  }

  var body: some View {
    Button(role: role) {
      Task {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }
        await action()
      }
    } label: {
      label(isRunning)
    }
    .animation(.default, value: isRunning)
    .onChange(of: isRunning) {
      onIsRunningChanged?($1)
    }
  }
}

extension AsyncButton {

  func onIsRunningChanged(_ action: @escaping (Bool) -> Void) -> Self {
    var view = self
    view.onIsRunningChanged = action
    return view
  }

}

#Preview {
  VStack(spacing: 20) {
    AsyncButton {
      do {
        try await Task.sleep(for: .seconds(2))
      } catch {
        dump(error)
      }
    } label: { isRunning in
      Text("Button")
        .overlayProgressView(isActive: isRunning)
    }
    .buttonStyle(.primary())

    AsyncButton {
      do {
        try await Task.sleep(for: .seconds(2))
      } catch {
        dump(error)
      }
    } label: { isRunning in
      Text("Button")
        .padding(12)
        .frame(maxWidth: .infinity)
        .overlayProgressView(isActive: isRunning)
        .overlay {
          RoundedRectangle(cornerRadius: 6)
            .stroke(.secondary, lineWidth: 1)
        }
    }
  }
  .padding()
}

#endif
