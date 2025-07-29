//
//  APIClient.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import FactoryKit
import Foundation
import RequestBuilder

extension Container {

    var apiClient: Factory<URLSessionManager> {
        self { BaseSessionManager(base: URL(string: ""), session: .shared) }
            .cached
    }

}
