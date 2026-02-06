//
//  View+TaskOnce.swift
//  Clerk
//

#if os(iOS)

import Foundation
import SwiftUI

private struct TaskOnce: ViewModifier {
  let task: () async -> Void

  @State private var hasAppeared = false

  func body(content: Content) -> some View {
    content.onAppear {
      guard !hasAppeared else { return }
      hasAppeared = true
      Task { await task() }
    }
  }
}

extension View {
  func taskOnce(_ task: @escaping () async -> Void) -> some View {
    modifier(TaskOnce(task: task))
  }
}

#endif
