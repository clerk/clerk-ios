//
//  ClerkURLEncodedFormEncoderRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 7/25/25.
//

import Foundation

struct ClerkURLEncodedFormEncoderRequestProcessor: RequestPreprocessor {
    static func process(request: inout URLRequest) async throws {
        if let data = request.httpBody {
            // Encode as URL-encoded form using Foundation types only.
            if let foundationJson = try? JSONSerialization.jsonObject(with: data),
               let encoded = try? URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(foundationJson)
            {
                request.httpBody = encoded
            }
        }
    }
}
