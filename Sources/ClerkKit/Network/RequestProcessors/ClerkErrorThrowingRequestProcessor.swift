//
//  ClerkErrorThrowingRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkErrorThrowingRequestProcessor: RequestPostprocessor {

    static func process(response: HTTPURLResponse, data: Data, context: RequestPipelineContext) throws {
        if response.isError {
            // ...and the response has a ClerkError body throw a custom clerk error
            if let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
               var clerkAPIError = clerkErrorResponse.errors.first
            {
                clerkAPIError.clerkTraceId = clerkErrorResponse.clerkTraceId
                Logger.log(
                    level: .error,
                    scope: .network,
                    message: "Network request failed",
                    info: [
                        "endpoint": response.url?.absoluteString ?? "unknown",
                        "statusCode": response.statusCode
                    ],
                    error: clerkAPIError
                )
                throw clerkAPIError
            }
            
            // ...else throw a generic api error
            let error = URLError(.unknown)
            Logger.log(
                level: .error,
                scope: .network,
                message: "Network request failed",
                info: [
                    "endpoint": response.url?.absoluteString ?? "unknown",
                    "statusCode": response.statusCode
                ],
                error: error
            )
            throw error
        }
    }
    
}
