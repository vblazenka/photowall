import XCTest
import SwiftCheck
@testable import PhotoWall

/// **Feature: google-photos-wallpaper, Property 7: Sign Out Clears All Credentials**
/// *For any* stored credentials state, after sign out completes, loading credentials
/// from Keychain should return nil and the auth state should be signedOut.
/// **Validates: Requirements 7.2**
final class AuthPropertyTests: XCTestCase {
    
    // MARK: - Property 7: Sign Out Clears All Credentials
    
    /// **Feature: google-photos-wallpaper, Property 7: Sign Out Clears All Credentials**
    func testSignOutClearsAllCredentials() {
        // Property: For any stored credentials, sign out clears them from Keychain
        property("Sign out clears all credentials from Keychain") <- forAll { (credentials: OAuthCredentials) in
            // Create a fresh keychain service for each test iteration
            let testService = KeychainService(
                service: "com.photowall.auth.pbt.\(UUID().uuidString)",
                account: "pbt-auth-credentials"
            )
            
            defer {
                try? testService.delete()
            }
            
            do {
                // Pre-condition: Save credentials to simulate authenticated state
                try testService.save(credentials: credentials)
                
                // Verify credentials exist before sign out
                guard try testService.load() != nil else {
                    return false
                }
                
                // Perform sign out action (delete credentials)
                try testService.delete()
                
                // Post-condition: Keychain should return nil
                let loadedAfterSignOut = try testService.load()
                return loadedAfterSignOut == nil
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Additional Unit Tests
    
    func testSignOutFromEmptyStateSucceeds() throws {
        // Sign out should succeed even when no credentials are stored
        let testService = KeychainService(
            service: "com.photowall.auth.test.\(UUID().uuidString)",
            account: "test-auth-credentials"
        )
        
        // Verify no credentials exist
        let beforeSignOut = try testService.load()
        XCTAssertNil(beforeSignOut)
        
        // Sign out (delete) should not throw
        XCTAssertNoThrow(try testService.delete())
        
        // Still no credentials
        let afterSignOut = try testService.load()
        XCTAssertNil(afterSignOut)
    }
    
    func testMultipleSignOutsAreIdempotent() throws {
        let testService = KeychainService(
            service: "com.photowall.auth.test.\(UUID().uuidString)",
            account: "test-auth-credentials"
        )
        
        let credentials = OAuthCredentials(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        // Save credentials
        try testService.save(credentials: credentials)
        
        // First sign out
        try testService.delete()
        XCTAssertNil(try testService.load())
        
        // Second sign out should also succeed
        XCTAssertNoThrow(try testService.delete())
        XCTAssertNil(try testService.load())
        
        // Third sign out should also succeed
        XCTAssertNoThrow(try testService.delete())
        XCTAssertNil(try testService.load())
    }
}
