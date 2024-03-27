//
//  KeychainManager.swift
//
//
//  Created by Mike Pitre on 3/27/24.
//

import Foundation

enum KeychainError: Error {
    case saveError
    case retrievalError
    case updateError
    case deleteError
    case deleteAllError
}

struct KeychainManager {
    
    static func save(_ data: Data, forKey key: String) throws {
        
        // Prepare attributes for the keychain item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item before saving if it exists
        SecItemDelete(query as CFDictionary)
        
        // Add the new item to the keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else { throw KeychainError.saveError }
    }
    
    static func retrieve(forKey key: String) throws -> Data? {
        // Prepare query to retrieve the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { throw KeychainError.retrievalError }
        guard let data = result as? Data else { return nil }
        return data
    }
    
    static func update(data: Data, forKey key: String) throws {
        
        // Prepare query to update the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        // Prepare attributes to update
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // Update the item in the keychain
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else { throw KeychainError.updateError }
    }
    
    static func deleteItem(forKey key: String) throws {
        // Prepare query to delete the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        // Delete the item from the keychain
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess else { throw KeychainError.deleteError }
    }
    
    static func deleteAllItems() throws {
        // Prepare query to delete all items
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        // Delete all items from the keychain
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess else { throw KeychainError.deleteAllError }
    }
}

