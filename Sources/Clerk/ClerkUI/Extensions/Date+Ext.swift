//
//  Date+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 5/29/25.
//

#if os(iOS)

  import Foundation

  extension Date {

    var relativeNamedFormat: String {
      var formatStyle = Date.RelativeFormatStyle()
      formatStyle.presentation = .named
      return self.formatted(formatStyle)
    }

  }

#endif
