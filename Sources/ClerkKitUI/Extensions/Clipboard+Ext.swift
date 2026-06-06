//
//  Clipboard+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

func copyToClipboard(_ text: String) {
  #if os(iOS)
  UIPasteboard.general.string = text
  #elseif os(macOS)
  NSPasteboard.general.clearContents()
  NSPasteboard.general.setString(text, forType: .string)
  #endif
}

#endif
