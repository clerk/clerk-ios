//
//  URLRequestBuilder+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation
import RequestBuilder

extension URLRequestBuilder {

    /// Adds the current Clerk session id to request URL.
    @discardableResult @MainActor
    func addClerkSessionId() -> Self {
        map {
            if let url = request.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.queryItems = (components.queryItems ?? []) + [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
                $0.request.url = components.url
            }
        }
    }

    /// Given an encodable data type, sets the request body to x-www-form-urlencoded data .
    @discardableResult
    public func body<DataType: Encodable>(formEncode data: DataType) -> Self {
        return map {
            if let data: Data = try? URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(data) {
                $0.add(value: "application/x-www-form-urlencoded", forHeader: "Content-Type")
                $0.request.httpBody = data
            }
        }
    }

}
