import XCTest
import SwiftCheck
@testable import PhotoWall

/// **Feature: google-photos-wallpaper, Property 1: Keychain Credentials Round-Trip**
/// *For any* valid OAuth credentials (access token, refresh token, expiration date),
/// saving to Keychain then loading should return credentials with equivalent values.
/// **Validates: Requirements 1.3**
final class KeychainPropertyTests: XCTestCase {
    
    private var keychainService: KeychainService!
    
    override func setUp() {
        super.setUp()
        // Use a unique service name for testing to avoid conflicts
        keychainService = KeychainService(
            service: "com.photowall.test.\(UUID().uuidString)",
            account: "test-credentials"
        )
    }
    
    override func tearDown() {
        // Clean up test keychain entries
        try? keychainService.delete()
        keychainService = nil
        super.tearDown()
    }
    
    // MARK: - Property 1: Keychain Credentials Round-Trip
    
    /// **Feature: google-photos-wallpaper, Property 1: Keychain Credentials Round-Trip**
    func testKeychainCredentialsRoundTrip() {
        // Property: For any valid OAuthCredentials, save then load returns equivalent values
        property("Keychain round-trip preserves credentials") <- forAll { (credentials: OAuthCredentials) in
            // Create a fresh keychain service for each test iteration
            let testService = KeychainService(
                service: "com.photowall.pbt.\(UUID().uuidString)",
                account: "pbt-credentials"
            )
            
            defer {
                try? testService.delete()
            }
            
            do {
                // Save credentials
                try testService.save(credentials: credentials)
                
                // Load credentials
                guard let loaded = try testService.load() else {
                    return false
                }
                
                // Verify equivalence
                return loaded.accessToken == credentials.accessToken
                    && loaded.refreshToken == credentials.refreshToken
                    && abs(loaded.expiresAt.timeIntervalSince(credentials.expiresAt)) < 1.0
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Additional Unit Tests for Edge Cases
    
    func testLoadReturnsNilWhenNoCredentialsStored() throws {
        let result = try keychainService.load()
        XCTAssertNil(result, "Load should return nil when no credentials are stored")
    }
    
    func testDeleteSucceedsWhenNoCredentialsStored() {
        XCTAssertNoThrow(try keychainService.delete(), "Delete should not throw when no credentials exist")
    }
    
    func testSaveOverwritesExistingCredentials() throws {
        let firstCredentials = OAuthCredentials(
            accessToken: "first-token",
            refreshToken: "first-refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        let secondCredentials = OAuthCredentials(
            accessToken: "second-token",
            refreshToken: "second-refresh",
            expiresAt: Date().addingTimeInterval(7200)
        )
        
        // Save first credentials
        try keychainService.save(credentials: firstCredentials)
        
        // Save second credentials (should overwrite)
        try keychainService.save(credentials: secondCredentials)
        
        // Load and verify second credentials are returned
        let loaded = try keychainService.load()
        XCTAssertEqual(loaded?.accessToken, secondCredentials.accessToken)
        XCTAssertEqual(loaded?.refreshToken, secondCredentials.refreshToken)
    }
    
    func testDeleteRemovesStoredCredentials() throws {
        let credentials = OAuthCredentials(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        // Save credentials
        try keychainService.save(credentials: credentials)
        
        // Verify they exist
        let beforeDelete = try keychainService.load()
        XCTAssertNotNil(beforeDelete)
        
        // Delete credentials
        try keychainService.delete()
        
        // Verify they're gone
        let afterDelete = try keychainService.load()
        XCTAssertNil(afterDelete)
    }
}
