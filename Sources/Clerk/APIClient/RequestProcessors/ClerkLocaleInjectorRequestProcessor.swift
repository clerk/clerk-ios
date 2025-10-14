//
//  ClerkLocaleInjectorRequestProcessor.swift
//  Clerk
//
//  Created by Cursor Agent on 10/14/25.
//

import Foundation

struct ClerkLocaleInjectorRequestProcessor: RequestPreprocessor {
    static func process(request: inout URLRequest) async throws {
        // Only inject for sign up create endpoints
        guard let url = request.url, url.path.hasSuffix("/v1/client/sign_ups"),
              request.httpMethod == "POST",
              let body = request.httpBody
        else { return }

        // Parse into Foundation JSON and merge locale
        guard var jsonObject = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] else { return }
        // Do not override pre-set locale if present
        if jsonObject["locale"] == nil {
            jsonObject["locale"] = LocaleUtils.userLocale()
            if let newData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                request.httpBody = newData
            }
        }
    }
}
