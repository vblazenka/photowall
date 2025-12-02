import XCTest
import SwiftCheck
@testable import PhotoWall

/// Property-based tests for SettingsManager
/// **Feature: google-photos-wallpaper, Property 4: Settings Persistence Round-Trip**
final class SettingsPropertyTests: XCTestCase {
    
    // MARK: - Property 4: Settings Persistence Round-Trip
    
    /// **Feature: google-photos-wallpaper, Property 4: Settings Persistence Round-Trip**
    /// *For any* valid rotation interval value, saving the interval to UserDefaults
    /// then loading should return the same interval value.
    /// **Validates: Requirements 3.2**
    func testRotationIntervalRoundTrip() {
        let intervals: [TimeInterval] = [300, 900, 1800, 3600, 86400]
        let generator = Gen<TimeInterval>.fromElements(of: intervals)
        
        property("Saving then loading rotation interval returns same value") <- forAll(generator) { (interval: TimeInterval) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            // Create manager and set interval
            let manager = SettingsManager(userDefaults: testDefaults)
            manager.rotationInterval = interval
            
            // Create new manager to load persisted value
            let loadedManager = SettingsManager(userDefaults: testDefaults)
            
            return loadedManager.rotationInterval == interval
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 4: Settings Persistence Round-Trip**
    /// *For any* array of album IDs, saving then loading should return the same array.
    /// **Validates: Requirements 3.2**
    func testSelectedAlbumIdsRoundTrip() {
        let generator = SettingsPropertyTests.stringArrayGenerator
        
        property("Saving then loading album IDs returns same value") <- forAll(generator) { (albumIds: [String]) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)
            manager.selectedAlbumIds = albumIds
            
            let loadedManager = SettingsManager(userDefaults: testDefaults)
            
            return loadedManager.selectedAlbumIds == albumIds
        }
    }

    
    /// **Feature: google-photos-wallpaper, Property 4: Settings Persistence Round-Trip**
    /// *For any* array of photo IDs, saving then loading should return the same array.
    /// **Validates: Requirements 3.2**
    func testSelectedPhotoIdsRoundTrip() {
        let generator = SettingsPropertyTests.stringArrayGenerator
        
        property("Saving then loading photo IDs returns same value") <- forAll(generator) { (photoIds: [String]) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)
            manager.selectedPhotoIds = photoIds
            
            let loadedManager = SettingsManager(userDefaults: testDefaults)
            
            return loadedManager.selectedPhotoIds == photoIds
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 4: Settings Persistence Round-Trip**
    /// *For any* boolean isPaused value, saving then loading should return the same value.
    /// **Validates: Requirements 3.2**
    func testIsPausedRoundTrip() {
        property("Saving then loading isPaused returns same value") <- forAll { (isPaused: Bool) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)
            manager.isPaused = isPaused
            
            let loadedManager = SettingsManager(userDefaults: testDefaults)
            
            return loadedManager.isPaused == isPaused
        }
    }
    
    // MARK: - Generators
    
    /// Generator for arrays of ID strings
    private static var stringArrayGenerator: Gen<[String]> {
        Gen<[String]>.compose { c in
            let count = c.generate(using: Gen<Int>.fromElements(in: 0...20))
            return (0..<count).map { _ in
                let length = Int.random(in: 10...30)
                let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
                return String((0..<length).map { _ in chars.randomElement()! })
            }
        }
    }
}
