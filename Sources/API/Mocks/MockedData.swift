//
//  MockedData.swift
//
//
//  Created by Mike Pitre on 2/9/24.
//

import Foundation

extension Clerk {
    
    public static var mock: Clerk {
        let clerk = Clerk()
        clerk.client = try! JSONDecoder.clerkDecoder.decode(ClientResponse<Client>.self, from: Data(MockClientJSON.utf8)).response
        clerk.environment = try! JSONDecoder.clerkDecoder.decode(Environment.self, from: Data(MockEnvironmentJSON.utf8))
        let user = try! JSONDecoder.clerkDecoder.decode(User.self, from: Data(MockUserJSON.utf8))
        clerk.sessionsByUserId[user.id] = try! JSONDecoder.clerkDecoder.decode([Session].self, from: Data(MockSessionsJSON.utf8))
        return clerk
    }
    
}
