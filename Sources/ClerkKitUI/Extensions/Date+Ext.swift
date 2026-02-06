//
//  Date+Ext.swift
//  Clerk
//

#if os(iOS)

import Foundation

extension Date {
  var relativeNamedFormat: String {
    var formatStyle = Date.RelativeFormatStyle()
    formatStyle.presentation = .named
    return formatted(formatStyle)
  }
}

#endif
