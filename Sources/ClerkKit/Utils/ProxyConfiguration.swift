//
//  ProxyConfiguration.swift
//  Clerk
//
//  Created by Mike Pitre on 2/13/25.
//

import Foundation

struct ProxyConfiguration: Sendable {
    let baseURL: URL
    let pathSegments: [String]

    init?(url: URL?) {
        guard let url else { return nil }
        guard let scheme = url.scheme, let host = url.host else { return nil }

        var baseComponents = URLComponents()
        baseComponents.scheme = scheme
        baseComponents.host = host
        baseComponents.port = url.port

        guard let baseURL = baseComponents.url else { return nil }

        self.baseURL = baseURL

        let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.isEmpty {
            self.pathSegments = []
        } else {
            self.pathSegments = trimmedPath.split(separator: "/").map { String($0) }
        }
    }

    func prefixedPath(for originalPath: String) -> String {
        let normalizedOriginal = normalize(originalPath)
        guard !pathSegments.isEmpty else {
            return normalizedOriginal
        }

        let originalSegments = segments(from: normalizedOriginal)

        if originalSegments.starts(with: pathSegments) {
            return "/" + originalSegments.joined(separator: "/")
        }

        var combined = pathSegments
        combined.append(contentsOf: originalSegments)
        return "/" + combined.joined(separator: "/")
    }

    private func normalize(_ path: String) -> String {
        guard !path.isEmpty else { return "/" }
        if path.hasPrefix("/") {
            return path
        }
        return "/" + path
    }

    private func segments(from path: String) -> [String] {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return [] }
        return trimmed.split(separator: "/").map { String($0) }
    }
}
