import XCTest
import SwiftCheck
@testable import PhotoWall

/// **Feature: google-photos-wallpaper, Property 6: Image Cache Round-Trip**
/// *For any* photo and its image data, caching the image then retrieving it
/// should return data that is byte-equivalent to the original.
/// **Validates: Requirements 5.3**
final class ImageCachePropertyTests: XCTestCase {
    
    private var cacheService: ImageCacheService!
    private var testCacheDirectory: String!
    
    override func setUp() {
        super.setUp()
        // Use a unique cache directory for testing to avoid conflicts
        testCacheDirectory = "TestCache-\(UUID().uuidString)"
        cacheService = ImageCacheService(cacheDirectoryName: testCacheDirectory)
    }
    
    override func tearDown() {
        // Clean up test cache
        try? cacheService.clearCache()
        cacheService = nil
        testCacheDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Property 6: Image Cache Round-Trip
    
    /// **Feature: google-photos-wallpaper, Property 6: Image Cache Round-Trip**
    func testImageCacheRoundTrip() {
        property("Image cache round-trip preserves byte-equivalent data") <- forAll { (photo: Photo) in
            // Create a fresh cache service for each test iteration
            let testDir = "PBTCache-\(UUID().uuidString)"
            let testCache = ImageCacheService(cacheDirectoryName: testDir)
            
            defer {
                try? testCache.clearCache()
            }
            
            // Generate random image data (simulating actual image bytes)
            let dataSize = Int.random(in: 100...10000)
            var imageData = Data(count: dataSize)
            for i in 0..<dataSize {
                imageData[i] = UInt8.random(in: 0...255)
            }
            
            do {
                // Cache the image
                let cachedURL = try testCache.cacheImage(for: photo, data: imageData)
                
                // Verify the cached URL exists
                guard FileManager.default.fileExists(atPath: cachedURL.path) else {
                    return false
                }
                
                // Retrieve the cached image URL
                guard let retrievedURL = testCache.getCachedImage(for: photo) else {
                    return false
                }

                
                // Read the data from the cached file
                let retrievedData = try Data(contentsOf: retrievedURL)
                
                // Verify byte-equivalence
                return retrievedData == imageData
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Additional Unit Tests for Edge Cases
    
    func testGetCachedImageReturnsNilWhenNotCached() {
        let photo = Photo(
            id: "uncached-photo-id",
            baseUrl: "https://example.com/photo",
            filename: "test.jpg",
            mimeType: "image/jpeg",
            mediaMetadata: nil
        )
        
        let result = cacheService.getCachedImage(for: photo)
        XCTAssertNil(result, "getCachedImage should return nil for uncached photos")
    }
    
    func testClearCacheRemovesAllCachedImages() throws {
        let photo1 = Photo(
            id: "photo-1",
            baseUrl: "https://example.com/photo1",
            filename: "test1.jpg",
            mimeType: "image/jpeg",
            mediaMetadata: nil
        )
        
        let photo2 = Photo(
            id: "photo-2",
            baseUrl: "https://example.com/photo2",
            filename: "test2.jpg",
            mimeType: "image/jpeg",
            mediaMetadata: nil
        )
        
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        
        // Cache two images
        _ = try cacheService.cacheImage(for: photo1, data: testData)
        _ = try cacheService.cacheImage(for: photo2, data: testData)
        
        // Verify they exist
        XCTAssertNotNil(cacheService.getCachedImage(for: photo1))
        XCTAssertNotNil(cacheService.getCachedImage(for: photo2))
        
        // Clear cache
        try cacheService.clearCache()
        
        // Verify they're gone
        XCTAssertNil(cacheService.getCachedImage(for: photo1))
        XCTAssertNil(cacheService.getCachedImage(for: photo2))
    }
    
    func testCacheSizeReturnsCorrectValue() throws {
        let photo = Photo(
            id: "size-test-photo",
            baseUrl: "https://example.com/photo",
            filename: "test.jpg",
            mimeType: "image/jpeg",
            mediaMetadata: nil
        )
        
        // Start with empty cache
        try cacheService.clearCache()
        XCTAssertEqual(cacheService.cacheSize(), 0)
        
        // Cache some data
        let testData = Data(repeating: 0xFF, count: 1000)
        _ = try cacheService.cacheImage(for: photo, data: testData)
        
        // Verify cache size is at least the data size
        XCTAssertGreaterThanOrEqual(cacheService.cacheSize(), 1000)
    }
    
    func testCacheOverwritesExistingImage() throws {
        let photo = Photo(
            id: "overwrite-test-photo",
            baseUrl: "https://example.com/photo",
            filename: "test.jpg",
            mimeType: "image/jpeg",
            mediaMetadata: nil
        )
        
        let firstData = Data([0x01, 0x02, 0x03])
        let secondData = Data([0x04, 0x05, 0x06, 0x07, 0x08])
        
        // Cache first data
        _ = try cacheService.cacheImage(for: photo, data: firstData)
        
        // Cache second data (should overwrite)
        _ = try cacheService.cacheImage(for: photo, data: secondData)
        
        // Retrieve and verify second data is returned
        guard let cachedURL = cacheService.getCachedImage(for: photo) else {
            XCTFail("Cached image should exist")
            return
        }
        
        let retrievedData = try Data(contentsOf: cachedURL)
        XCTAssertEqual(retrievedData, secondData)
    }
    
    func testCacheHandlesPhotoIdWithSpecialCharacters() throws {
        let photo = Photo(
            id: "photo/with/slashes/in/id",
            baseUrl: "https://example.com/photo",
            filename: "test.jpg",
            mimeType: "image/jpeg",
            mediaMetadata: nil
        )
        
        let testData = Data([0x01, 0x02, 0x03])
        
        // Should not throw
        let cachedURL = try cacheService.cacheImage(for: photo, data: testData)
        XCTAssertNotNil(cachedURL)
        
        // Should be retrievable
        let retrieved = cacheService.getCachedImage(for: photo)
        XCTAssertNotNil(retrieved)
    }
}
