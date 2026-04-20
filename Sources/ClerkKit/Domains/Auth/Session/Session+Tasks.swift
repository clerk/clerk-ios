//
//  Session+Tasks.swift
//

import Foundation

extension Session {
  public var pendingTasks: [Task] {
    tasks ?? []
  }
}
