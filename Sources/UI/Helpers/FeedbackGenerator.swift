//
//  FeedbackGenerator.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import Foundation
import UIKit

@MainActor
enum FeedbackGenerator {
    
    private static let generator = UINotificationFeedbackGenerator()
    
    static func success() {
        generator.notificationOccurred(.success)
    }
    
    static func error() {
        generator.notificationOccurred(.error)
    }
    
    static func warning() {
        generator.notificationOccurred(.warning)
    }
    
}

#endif
