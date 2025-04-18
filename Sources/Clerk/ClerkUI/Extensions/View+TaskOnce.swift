//
//  TaskOnce.swift
//  Clerk
//
//  Created by Mike Pitre on 4/18/25.
//

import Foundation
import SwiftUI

public extension View {
  func taskOnce(_ task: @escaping () async -> ()) -> some View {
    modifier(TaskOnce(task: task))
  }
}

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
