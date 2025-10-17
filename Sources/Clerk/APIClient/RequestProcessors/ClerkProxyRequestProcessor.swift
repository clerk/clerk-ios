//
//  ClerkProxyRequestProcessor.swift
//  Clerk
//
//  Created by Mike Pitre on 2/13/25.
//

import Foundation

struct ClerkProxyRequestProcessor: RequestPreprocessor {

    /// Ensures request URLs include the proxy path prefix when a proxy URL is configured.
    @MainActor
    static func process(request: inout URLRequest) async throws {
        let configuration = Clerk.shared.proxyConfiguration

        guard
            let proxyConfiguration = configuration,
            !proxyConfiguration.pathSegments.isEmpty,
            let url = request.url,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return
        }

        // Prefix the proxy path so absolute request URLs do not clobber it.
        let currentPath = components.path
        let updatedPath = proxyConfiguration.prefixedPath(for: currentPath)

        if currentPath == updatedPath {
            return
        }

        components.path = updatedPath

        if let updatedURL = components.url {
            request.url = updatedURL
        }
    }

}
