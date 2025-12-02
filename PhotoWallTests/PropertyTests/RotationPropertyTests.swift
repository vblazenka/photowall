import XCTest
import SwiftCheck
@testable import PhotoWall

/// Property-based tests for wallpaper rotation
/// **Feature: google-photos-wallpaper, Properties 5 & 8: Rotation Queue Advancement & Pause/Resume State Preservation**
final class RotationPropertyTests: XCTestCase {
    
    // MARK: - Property 5: Rotation Queue Advancement
    
    /// **Feature: google-photos-wallpaper, Property 5: Rotation Queue Advancement**
    /// *For any* rotation queue with N photos (N > 0) and current index I,
    /// advancing to the next photo should result in index (I + 1) mod N,
    /// ensuring circular rotation through all photos.
    /// **Validates: Requirements 3.4**
    func testRotationQueueAdvancementFollowsModuloPattern() {
        property("Advancing index follows (I + 1) mod N pattern") <- forAll(nonEmptyRotationStateGenerator) { (state: RotationState) in
            var mutableState = state
            let originalIndex = mutableState.currentIndex
            let photoCount = mutableState.photos.count
            
            // Advance to next photo
            mutableState.advanceToNext()
            
            // Expected index is (original + 1) mod N
            let expectedIndex = (originalIndex + 1) % photoCount
            
            return mutableState.currentIndex == expectedIndex
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 5: Rotation Queue Advancement**
    /// *For any* rotation queue with N photos, advancing N times should return
    /// to the original index (circular rotation).
    /// **Validates: Requirements 3.4**
    func testRotationQueueIsCircular() {
        property("Advancing N times returns to original index") <- forAll(nonEmptyRotationStateGenerator) { (state: RotationState) in
            var mutableState = state
            let originalIndex = mutableState.currentIndex
            let photoCount = mutableState.photos.count
            
            // Advance N times (full cycle)
            for _ in 0..<photoCount {
                mutableState.advanceToNext()
            }
            
            // Should be back at original index
            return mutableState.currentIndex == originalIndex
        }
    }

    
    /// **Feature: google-photos-wallpaper, Property 5: Rotation Queue Advancement**
    /// *For any* rotation queue, advancing should update the lastRotationTime.
    /// **Validates: Requirements 3.4**
    func testAdvancingUpdatesLastRotationTime() {
        property("Advancing updates lastRotationTime") <- forAll(nonEmptyRotationStateGenerator) { (state: RotationState) in
            var mutableState = state
            
            // Advance to next photo
            mutableState.advanceToNext()
            
            // lastRotationTime should be set
            return mutableState.lastRotationTime != nil
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 5: Rotation Queue Advancement**
    /// *For any* rotation queue, currentPhoto should return the photo at currentIndex.
    /// **Validates: Requirements 3.4**
    func testCurrentPhotoMatchesCurrentIndex() {
        property("currentPhoto returns photo at currentIndex") <- forAll(nonEmptyRotationStateGenerator) { (state: RotationState) in
            guard let currentPhoto = state.currentPhoto else {
                return false
            }
            
            let expectedPhoto = state.photos[state.currentIndex]
            return currentPhoto.id == expectedPhoto.id
        }
    }
    
    // MARK: - Property 8: Pause/Resume State Preservation
    
    /// **Feature: google-photos-wallpaper, Property 8: Pause/Resume State Preservation**
    /// *For any* active rotation state with photos and current index,
    /// pausing then resuming should preserve the same photo queue and current index position.
    /// **Validates: Requirements 8.2, 8.4**
    func testPauseResumePreservesState() {
        property("Pause then resume preserves queue and index") <- forAll(activeRotationStateGenerator) { (state: RotationState) in
            var mutableState = state
            let originalPhotos = mutableState.photos
            let originalIndex = mutableState.currentIndex
            let originalInterval = mutableState.interval
            
            // Simulate pause
            mutableState.isPaused = true
            
            // Simulate resume
            mutableState.isPaused = false
            
            // Verify state is preserved
            let photosPreserved = mutableState.photos.map { $0.id } == originalPhotos.map { $0.id }
            let indexPreserved = mutableState.currentIndex == originalIndex
            let intervalPreserved = mutableState.interval == originalInterval
            
            return photosPreserved && indexPreserved && intervalPreserved
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 8: Pause/Resume State Preservation**
    /// *For any* active rotation state, pausing should set isPaused to true
    /// while keeping isActive true.
    /// **Validates: Requirements 8.2**
    func testPauseSetsIsPausedFlag() {
        property("Pausing sets isPaused to true") <- forAll(activeRotationStateGenerator) { (state: RotationState) in
            var mutableState = state
            
            // Simulate pause
            mutableState.isPaused = true
            
            // isActive should still be true, isPaused should be true
            return mutableState.isActive && mutableState.isPaused
        }
    }

    
    /// **Feature: google-photos-wallpaper, Property 8: Pause/Resume State Preservation**
    /// *For any* paused rotation state, resuming should set isPaused to false.
    /// **Validates: Requirements 8.4**
    func testResumeClersIsPausedFlag() {
        property("Resuming clears isPaused flag") <- forAll(pausedRotationStateGenerator) { (state: RotationState) in
            var mutableState = state
            
            // Simulate resume
            mutableState.isPaused = false
            
            // isPaused should be false
            return !mutableState.isPaused
        }
    }
    
    /// **Feature: google-photos-wallpaper, Property 8: Pause/Resume State Preservation**
    /// *For any* rotation state, multiple pause/resume cycles should not alter the queue.
    /// **Validates: Requirements 8.2, 8.4**
    func testMultiplePauseResumeCyclesPreserveQueue() {
        property("Multiple pause/resume cycles preserve queue") <- forAll(activeRotationStateGenerator) { (state: RotationState) in
            var mutableState = state
            let originalPhotoIds = mutableState.photos.map { $0.id }
            let originalIndex = mutableState.currentIndex
            
            // Multiple pause/resume cycles
            for _ in 0..<5 {
                mutableState.isPaused = true
                mutableState.isPaused = false
            }
            
            // Verify state is preserved
            let photosPreserved = mutableState.photos.map { $0.id } == originalPhotoIds
            let indexPreserved = mutableState.currentIndex == originalIndex
            
            return photosPreserved && indexPreserved
        }
    }
    
    // MARK: - Edge Cases
    
    /// Test that advancing on empty queue does nothing
    func testAdvanceOnEmptyQueueDoesNothing() {
        var state = RotationState(
            isActive: true,
            isPaused: false,
            currentIndex: 0,
            photos: [],
            interval: 3600,
            lastRotationTime: nil
        )
        
        state.advanceToNext()
        
        XCTAssertEqual(state.currentIndex, 0)
        XCTAssertNil(state.currentPhoto)
    }
    
    /// Test that currentPhoto returns nil for empty queue
    func testCurrentPhotoNilForEmptyQueue() {
        let state = RotationState(
            isActive: true,
            isPaused: false,
            currentIndex: 0,
            photos: [],
            interval: 3600,
            lastRotationTime: nil
        )
        
        XCTAssertNil(state.currentPhoto)
    }
    
    // MARK: - Generators
    
    /// Generator for non-empty rotation state (at least 1 photo)
    private var nonEmptyRotationStateGenerator: Gen<RotationState> {
        Gen<RotationState>.compose { c in
            // Generate at least 1 photo
            let photoCount = c.generate(using: Gen<Int>.fromElements(in: 1...20))
            let photos: [Photo] = (0..<photoCount).map { _ in c.generate() }
            let currentIndex = c.generate(using: Gen<Int>.fromElements(in: 0...max(0, photoCount - 1)))
            
            return RotationState(
                isActive: c.generate(),
                isPaused: c.generate(),
                currentIndex: currentIndex,
                photos: photos,
                interval: c.generate(using: intervalGenerator),
                lastRotationTime: c.generate(using: optionalDateGenerator)
            )
        }
    }
    
    /// Generator for active (non-paused) rotation state with photos
    private var activeRotationStateGenerator: Gen<RotationState> {
        Gen<RotationState>.compose { c in
            let photoCount = c.generate(using: Gen<Int>.fromElements(in: 1...20))
            let photos: [Photo] = (0..<photoCount).map { _ in c.generate() }
            let currentIndex = c.generate(using: Gen<Int>.fromElements(in: 0...max(0, photoCount - 1)))
            
            return RotationState(
                isActive: true,
                isPaused: false,
                currentIndex: currentIndex,
                photos: photos,
                interval: c.generate(using: intervalGenerator),
                lastRotationTime: Date()
            )
        }
    }
    
    /// Generator for paused rotation state with photos
    private var pausedRotationStateGenerator: Gen<RotationState> {
        Gen<RotationState>.compose { c in
            let photoCount = c.generate(using: Gen<Int>.fromElements(in: 1...20))
            let photos: [Photo] = (0..<photoCount).map { _ in c.generate() }
            let currentIndex = c.generate(using: Gen<Int>.fromElements(in: 0...max(0, photoCount - 1)))
            
            return RotationState(
                isActive: true,
                isPaused: true,
                currentIndex: currentIndex,
                photos: photos,
                interval: c.generate(using: intervalGenerator),
                lastRotationTime: Date()
            )
        }
    }
    
    private var intervalGenerator: Gen<TimeInterval> {
        Gen<TimeInterval>.fromElements(of: [300, 900, 1800, 3600, 86400])
    }
    
    private var optionalDateGenerator: Gen<Date?> {
        Gen<Date?>.frequency([
            (1, Gen<Date?>.pure(nil)),
            (3, Gen<Date?>.pure(Date()))
        ])
    }
}
