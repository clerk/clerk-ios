//
//  NSImage+Ext.swift
//  Clerk
//

#if os(macOS)

import AppKit

extension NSImage {
  func resizedMaintainingAspectRatio(to targetSize: CGSize) -> NSImage {
    let aspectRatio = size.width / size.height
    let targetAspectRatio = targetSize.width / targetSize.height

    let newSize = if aspectRatio > targetAspectRatio {
      CGSize(width: targetSize.width, height: targetSize.width / aspectRatio)
    } else {
      CGSize(width: targetSize.height * aspectRatio, height: targetSize.height)
    }

    let image = NSImage(size: newSize)
    image.lockFocus()
    defer { image.unlockFocus() }

    draw(
      in: CGRect(origin: .zero, size: newSize),
      from: CGRect(origin: .zero, size: size),
      operation: .copy,
      fraction: 1
    )

    return image
  }

  func jpegData(compressionQuality: CGFloat) -> Data? {
    guard
      let tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffRepresentation)
    else {
      return nil
    }

    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
  }
}

#endif
