import Foundation
import Security

struct KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.jbank.auth" // Unique identifier for your app's keychain entries

    private init() {}

    func save(token: String, for account: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            print("Keychain Error: Failed to convert token to data.")
            return false
        }
        
        // 1. Check for existing item to avoid duplicates
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            // Item already exists, update it
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: tokenData
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if updateStatus != errSecSuccess {
                print("Keychain Error: Failed to update item. Status: \(updateStatus)")
                return false
            }
            print("Keychain Success: Token updated for account \(account).")
            return true
            
        case errSecItemNotFound:
            // Item does not exist, add it as a new one
            var newItem = query
            newItem[kSecValueData as String] = tokenData
            // Set accessibility to ensure the item is only available after the first unlock
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            if addStatus != errSecSuccess {
                print("Keychain Error: Failed to add new item. Status: \(addStatus)")
                return false
            }
            print("Keychain Success: Token saved for account \(account).")
            return true
            
        default:
            print("Keychain Error: Keychain read failed with status: \(status)")
            return false
        }
    }

    func read(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            guard let data = dataTypeRef as? Data,
                  let token = String(data: data, encoding: .utf8) else {
                print("Keychain Error: Failed to decode retrieved data.")
                return nil
            }
            print("Keychain Success: Token retrieved for account \(account).")
            return token
        } else {
            // Don't print an error if it's simply not found
            if status != errSecItemNotFound {
                print("Keychain Error: Read failed with status: \(status)")
            }
            return nil
        }
    }

    func delete(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            print("Keychain Success: Token deleted for account \(account).")
            return true
        } else if status == errSecItemNotFound {
            // If the item doesn't exist, we can consider the deletion successful
            print("Keychain Info: No token found to delete for account \(account).")
            return true
        } else {
            print("Keychain Error: Delete failed with status: \(status)")
            return false
        }
    }
}
