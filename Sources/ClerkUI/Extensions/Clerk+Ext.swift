//
//  Clerk+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/23/25.
//

import Foundation
import SwiftUI
import Clerk

extension EnvironmentValues {
    @MainActor @Entry public var clerk = Clerk.shared
}
