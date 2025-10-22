//
//  UIImage+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 5/15/25.
//

#if os(iOS)

import Foundation
import SwiftUI

extension UIImage {
    func resizedMaintainingAspectRatio(to targetSize: CGSize) -> UIImage {
        let aspectRatio = size.width / size.height
        let targetAspectRatio = targetSize.width / targetSize.height

        let newSize: CGSize
        if aspectRatio > targetAspectRatio {
            newSize = CGSize(width: targetSize.width, height: targetSize.width / aspectRatio)
        } else {
            newSize = CGSize(width: targetSize.height * aspectRatio, height: targetSize.height)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#endif
