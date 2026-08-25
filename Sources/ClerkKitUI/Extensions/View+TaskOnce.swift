//
//  View+TaskOnce.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

private struct TaskOnce: ViewModifier {
  let task: () async -> Void

  @State private var hasAppeared = false

  func body(content: Content) -> some View {
    content.task {
      guard !hasAppeared else { return }
      hasAppeared = true
      await task()
    }
  }
}

extension View {
  func taskOnce(_ task: @escaping () async -> Void) -> some View {
    modifier(TaskOnce(task: task))
  }
}

#endif
