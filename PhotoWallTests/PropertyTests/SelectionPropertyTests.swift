import XCTest
import SwiftCheck
@testable import PhotoWall

/// Property-based tests for photo and album selection
/// **Feature: google-photos-wallpaper, Properties 2 & 3: Photo Selection State Consistency & Album Selection**
final class SelectionPropertyTests: XCTestCase {
    
    // MARK: - Property 2: Photo Selection State Consistency
    
    /// **Feature: google-photos-wallpaper, Property 2: Photo Selection State Consistency**
    /// *For any* photo and selection action, after selecting a photo, the photo ID
    /// should appear in the selected photos set, and the set size should increase by one.
    /// **Validates: Requirements 2.3**
    func testSelectPhotoAddsIdToSelection() {
        property("Selecting a photo adds its ID to the selection") <- forAll { (photo: Photo) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)
            let initialCount = manager.selectedPhotoIds.count
            
            // Select the photo
            let wasAdded = manager.selectPhoto(photo)
            
            // Verify the photo ID is in the selection
            let containsPhoto = manager.selectedPhotoIds.contains(photo.id)
            
            // Verify the count increased by one (if it was actually added)
            let countIncreased = wasAdded ? (manager.selectedPhotoIds.count == initialCount + 1) : true
            
            return containsPhoto && countIncreased
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 2: Photo Selection State Consistency**
    /// *For any* photo that is already selected, selecting it again should not
    /// duplicate the ID in the selection.
    /// **Validates: Requirements 2.3**
    func testSelectPhotoIsIdempotent() {
        property("Selecting an already selected photo does not duplicate") <- forAll { (photo: Photo) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)

            
            // Select the photo twice
            manager.selectPhoto(photo)
            let countAfterFirst = manager.selectedPhotoIds.count
            
            manager.selectPhoto(photo)
            let countAfterSecond = manager.selectedPhotoIds.count
            
            // Count should remain the same
            return countAfterFirst == countAfterSecond
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 2: Photo Selection State Consistency**
    /// *For any* selected photo, deselecting it should remove its ID from the selection.
    /// **Validates: Requirements 2.3**
    func testDeselectPhotoRemovesIdFromSelection() {
        property("Deselecting a photo removes its ID from the selection") <- forAll { (photo: Photo) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)
            
            // Select then deselect
            manager.selectPhoto(photo)
            manager.deselectPhoto(photo)
            
            // Verify the photo ID is no longer in the selection
            return !manager.selectedPhotoIds.contains(photo.id)
        }
    }
    
    // MARK: - Property 3: Album Selection Includes All Photos
    
    /// **Feature: google-photos-wallpaper, Property 3: Album Selection Includes All Photos**
    /// *For any* album containing N photos, selecting that album should result in
    /// exactly N photos being added to the wallpaper rotation queue, with all
    /// photo IDs from the album present.
    /// **Validates: Requirements 2.4**
    func testSelectAlbumAddsAllPhotos() {
        property("Selecting an album adds all its photos to selection") <- forAll { (album: Album, photos: [Photo]) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)
            
            // Select the album with its photos
            let addedCount = manager.selectAlbum(album, photos: photos)
            
            // Verify all photo IDs are in the selection
            let allPhotosSelected = photos.allSatisfy { photo in
                manager.selectedPhotoIds.contains(photo.id)
            }
            
            // Verify the count matches (accounting for unique photos)
            let uniquePhotoIds = Set(photos.map { $0.id })
            let expectedCount = uniquePhotoIds.count
            
            return allPhotosSelected && addedCount == expectedCount
        }
    }

    
    /// **Feature: google-photos-wallpaper, Property 3: Album Selection Includes All Photos**
    /// *For any* album, selecting it should mark the album as selected.
    /// **Validates: Requirements 2.4**
    func testSelectAlbumMarksAlbumAsSelected() {
        property("Selecting an album marks it as selected") <- forAll { (album: Album, photos: [Photo]) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)
            
            // Select the album
            manager.selectAlbum(album, photos: photos)
            
            // Verify the album is marked as selected
            return manager.isAlbumSelected(album)
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 3: Album Selection Includes All Photos**
    /// *For any* selected album, deselecting it should remove all its photos from selection.
    /// **Validates: Requirements 2.4**
    func testDeselectAlbumRemovesAllPhotos() {
        property("Deselecting an album removes all its photos") <- forAll { (album: Album, photos: [Photo]) in
            let suiteName = "com.photowall.test.\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            defer {
                UserDefaults.standard.removePersistentDomain(forName: suiteName)
            }
            
            let manager = SettingsManager(userDefaults: testDefaults)
            
            // Select then deselect the album
            manager.selectAlbum(album, photos: photos)
            manager.deselectAlbum(album, photos: photos)
            
            // Verify no photo IDs from the album are in the selection
            let noPhotosSelected = photos.allSatisfy { photo in
                !manager.selectedPhotoIds.contains(photo.id)
            }
            
            // Verify the album is no longer marked as selected
            let albumNotSelected = !manager.isAlbumSelected(album)
            
            return noPhotosSelected && albumNotSelected
        }
    }
}
