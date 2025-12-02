import Foundation
import Combine

// MARK: - SettingsManagerProtocol

protocol SettingsManagerProtocol: ObservableObject {
    var rotationInterval: TimeInterval { get set }
    var selectedAlbumIds: [String] { get set }
    var selectedPhotoIds: [String] { get set }
    var isPaused: Bool { get set }
}

// MARK: - SettingsManager

final class SettingsManager: SettingsManagerProtocol {
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let rotationInterval = "com.photowall.rotationInterval"
        static let selectedAlbumIds = "com.photowall.selectedAlbumIds"
        static let selectedPhotoIds = "com.photowall.selectedPhotoIds"
        static let isPaused = "com.photowall.isPaused"
    }
    
    // MARK: - Default Values
    
    private enum Defaults {
        static let rotationInterval: TimeInterval = 3600 // 1 hour
    }
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    
    // MARK: - Published Properties
    
    @Published var rotationInterval: TimeInterval {
        didSet {
            userDefaults.set(rotationInterval, forKey: Keys.rotationInterval)
        }
    }
    
    @Published var selectedAlbumIds: [String] {
        didSet {
            userDefaults.set(selectedAlbumIds, forKey: Keys.selectedAlbumIds)
        }
    }
    
    @Published var selectedPhotoIds: [String] {
        didSet {
            userDefaults.set(selectedPhotoIds, forKey: Keys.selectedPhotoIds)
        }
    }
    
    @Published var isPaused: Bool {
        didSet {
            userDefaults.set(isPaused, forKey: Keys.isPaused)
        }
    }
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load persisted values or use defaults
        self.rotationInterval = userDefaults.object(forKey: Keys.rotationInterval) as? TimeInterval ?? Defaults.rotationInterval
        self.selectedAlbumIds = userDefaults.stringArray(forKey: Keys.selectedAlbumIds) ?? []
        self.selectedPhotoIds = userDefaults.stringArray(forKey: Keys.selectedPhotoIds) ?? []
        self.isPaused = userDefaults.bool(forKey: Keys.isPaused)
    }
    
    // MARK: - Convenience Methods
    
    /// Resets all settings to default values
    func resetToDefaults() {
        rotationInterval = Defaults.rotationInterval
        selectedAlbumIds = []
        selectedPhotoIds = []
        isPaused = false
    }
    
    /// Clears all stored settings from UserDefaults
    func clearAllSettings() {
        userDefaults.removeObject(forKey: Keys.rotationInterval)
        userDefaults.removeObject(forKey: Keys.selectedAlbumIds)
        userDefaults.removeObject(forKey: Keys.selectedPhotoIds)
        userDefaults.removeObject(forKey: Keys.isPaused)
    }
    
    // MARK: - Photo Selection Methods
    
    /// Adds a photo to the selection
    /// - Parameter photo: The photo to select
    /// - Returns: True if the photo was added (not already selected), false otherwise
    @discardableResult
    func selectPhoto(_ photo: Photo) -> Bool {
        guard !selectedPhotoIds.contains(photo.id) else { return false }
        selectedPhotoIds.append(photo.id)
        return true
    }
    
    /// Removes a photo from the selection
    /// - Parameter photo: The photo to deselect
    /// - Returns: True if the photo was removed, false if it wasn't selected
    @discardableResult
    func deselectPhoto(_ photo: Photo) -> Bool {
        guard let index = selectedPhotoIds.firstIndex(of: photo.id) else { return false }
        selectedPhotoIds.remove(at: index)
        return true
    }
    
    /// Checks if a photo is currently selected
    /// - Parameter photo: The photo to check
    /// - Returns: True if the photo is selected
    func isPhotoSelected(_ photo: Photo) -> Bool {
        selectedPhotoIds.contains(photo.id)
    }
    
    // MARK: - Album Selection Methods
    
    /// Adds all photos from an album to the selection
    /// - Parameters:
    ///   - album: The album to select
    ///   - photos: The photos contained in the album
    /// - Returns: The number of photos added to the selection
    @discardableResult
    func selectAlbum(_ album: Album, photos: [Photo]) -> Int {
        var addedCount = 0
        
        // Track the album as selected
        if !selectedAlbumIds.contains(album.id) {
            selectedAlbumIds.append(album.id)
        }
        
        // Add all photos from the album
        for photo in photos {
            if !selectedPhotoIds.contains(photo.id) {
                selectedPhotoIds.append(photo.id)
                addedCount += 1
            }
        }
        
        return addedCount
    }
    
    /// Removes all photos from an album from the selection
    /// - Parameters:
    ///   - album: The album to deselect
    ///   - photos: The photos contained in the album
    /// - Returns: The number of photos removed from the selection
    @discardableResult
    func deselectAlbum(_ album: Album, photos: [Photo]) -> Int {
        var removedCount = 0
        
        // Remove the album from selected albums
        if let index = selectedAlbumIds.firstIndex(of: album.id) {
            selectedAlbumIds.remove(at: index)
        }
        
        // Remove all photos from the album
        let photoIdsToRemove = Set(photos.map { $0.id })
        let originalCount = selectedPhotoIds.count
        selectedPhotoIds.removeAll { photoIdsToRemove.contains($0) }
        removedCount = originalCount - selectedPhotoIds.count
        
        return removedCount
    }
    
    /// Checks if an album is currently selected
    /// - Parameter album: The album to check
    /// - Returns: True if the album is selected
    func isAlbumSelected(_ album: Album) -> Bool {
        selectedAlbumIds.contains(album.id)
    }
    
    /// Returns the count of selected photos
    var selectedPhotoCount: Int {
        selectedPhotoIds.count
    }
}
