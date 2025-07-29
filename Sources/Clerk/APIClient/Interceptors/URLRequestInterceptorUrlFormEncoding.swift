//
//  URLRequestInterceptorUrlFormEncoding.swift
//  Clerk
//
//  Created by Mike Pitre on 7/25/25.
//

import Foundation
import RequestBuilder

final class URLRequestInterceptorUrlFormEncoding: URLRequestInterceptor, @unchecked Sendable {

    var parent: URLSessionManager!

    func request(forURL url: URL?) -> URLRequestBuilder {
        URLRequestBuilder(manager: self, builder: parent.request(forURL: url))
            .with { request in
                if let data = request.httpBody {
                    let json = try? JSONDecoder.clerkDecoder.decode(JSON.self, from: data)
                    request.httpBody = try? URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase).encode(json)
                }
            }
    }

}
