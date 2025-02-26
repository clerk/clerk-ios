//
//  InputStream+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 2/25/25.
//

import Foundation

extension URLRequest {
  
  var urlEncodedFormBody: [String: String] {
    guard let httpBodyStream else { return [:] }
    do {
      return try httpBodyStream.urlEncodedForm()
    } catch {
      return [:]
    }
  }
  
}

extension InputStream {
  /// Reads the data from the input stream and decodes it as a dictionary from URL-encoded form data.
  func urlEncodedForm() throws -> [String: String] {
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    var data = Data()
    
    open()
    defer { close() }
    
    while hasBytesAvailable {
      let bytesRead = read(&buffer, maxLength: bufferSize)
      if bytesRead < 0, let error = streamError {
        throw error
      }
      if bytesRead == 0 {
        break
      }
      data.append(buffer, count: bytesRead)
    }
    
    // Convert Data to URL-encoded string
    guard let bodyString = String(data: data, encoding: .utf8) else {
      throw NSError(domain: "InputStreamError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode input stream as UTF-8"])
    }
    
    // Parse URL-encoded form data into a dictionary
    var parameters: [String: String] = [:]
    let pairs = bodyString.split(separator: "&")
    for pair in pairs {
      let keyValue = pair.split(separator: "=", maxSplits: 1)
      if keyValue.count == 2 {
        let key = keyValue[0].removingPercentEncoding ?? String(keyValue[0])
        let value = keyValue[1].removingPercentEncoding ?? String(keyValue[1])
        parameters[key] = value
      }
    }
    
    return parameters
  }
}
