//
//  TaskOnce.swift
//  Clerk
//
//  Created by Mike Pitre on 4/18/25.
//

#if canImport(SwiftUI)

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
  func taskOnce(_ task: @escaping () async -> ()) -> some View {
    modifier(TaskOnce(task: task))
  }
}

#endif
