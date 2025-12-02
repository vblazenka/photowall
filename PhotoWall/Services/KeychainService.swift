import Foundation
import Security

// MARK: - KeychainError

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed
    case decodingFailed
    case unexpectedData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        case .encodingFailed:
            return "Failed to encode credentials"
        case .decodingFailed:
            return "Failed to decode credentials"
        case .unexpectedData:
            return "Unexpected data format in Keychain"
        }
    }
}

// MARK: - KeychainServiceProtocol

protocol KeychainServiceProtocol {
    func save(credentials: OAuthCredentials) throws
    func load() throws -> OAuthCredentials?
    func delete() throws
}

// MARK: - KeychainService

final class KeychainService: KeychainServiceProtocol {
    
    private let service: String
    private let account: String
    
    init(service: String = "com.photowall.oauth", account: String = "google-credentials") {
        self.service = service
        self.account = account
    }
    
    // MARK: - Save Credentials
    
    func save(credentials: OAuthCredentials) throws {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(credentials) else {
            throw KeychainError.encodingFailed
        }
        
        // Delete existing item first (if any)
        try? delete()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    // MARK: - Load Credentials
    
    func load() throws -> OAuthCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }
        
        let decoder = JSONDecoder()
        guard let credentials = try? decoder.decode(OAuthCredentials.self, from: data) else {
            throw KeychainError.decodingFailed
        }
        
        return credentials
    }
    
    // MARK: - Delete Credentials
    
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // errSecItemNotFound is acceptable - item may not exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
