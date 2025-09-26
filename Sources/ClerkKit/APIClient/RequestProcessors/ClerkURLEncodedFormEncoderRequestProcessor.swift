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
            let json = try? JSONDecoder.clerkDecoder.decode(JSON.self, from: data)
            request.httpBody = try? URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(json)
        }
    }
}
