import Foundation
import AppKit
import Combine

// MARK: - WallpaperError

enum WallpaperError: Error, LocalizedError {
    case noPhotosInQueue
    case downloadFailed(Error)
    case setWallpaperFailed(Error)
    case noDisplaysAvailable
    case invalidImageData
    case cacheError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noPhotosInQueue:
            return "No photos available in the rotation queue"
        case .downloadFailed(let error):
            return "Failed to download photo: \(error.localizedDescription)"
        case .setWallpaperFailed(let error):
            return "Failed to set wallpaper: \(error.localizedDescription)"
        case .noDisplaysAvailable:
            return "No displays available"
        case .invalidImageData:
            return "Invalid image data"
        case .cacheError(let error):
            return "Cache error: \(error.localizedDescription)"
        }
    }
}

// MARK: - WallpaperManagerProtocol

protocol WallpaperManagerProtocol: ObservableObject {
    var isRotating: Bool { get }
    var isPaused: Bool { get }
    var currentPhoto: Photo? { get }
    var rotationState: RotationState { get }
    
    func startRotation(photos: [Photo], interval: TimeInterval)
    func pauseRotation()
    func resumeRotation()
    func stopRotation()
    func setWallpaper(photo: Photo) async throws
}

// MARK: - WallpaperManager

final class WallpaperManager: WallpaperManagerProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var isRotating: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var currentPhoto: Photo?
    @Published private(set) var rotationState: RotationState

    
    // MARK: - Private Properties
    
    private let photosManager: PhotosManagerProtocol
    private let imageCacheService: ImageCacheServiceProtocol
    private var rotationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        photosManager: PhotosManagerProtocol,
        imageCacheService: ImageCacheServiceProtocol = ImageCacheService()
    ) {
        self.photosManager = photosManager
        self.imageCacheService = imageCacheService
        self.rotationState = RotationState(
            isActive: false,
            isPaused: false,
            currentIndex: 0,
            photos: [],
            interval: 3600,
            lastRotationTime: nil
        )
    }
    
    // MARK: - Wallpaper Setting
    
    /// Sets the wallpaper on all connected displays
    /// - Parameter photo: The photo to set as wallpaper
    func setWallpaper(photo: Photo) async throws {
        // Download and cache the full-resolution image
        let imageData: Data
        do {
            imageData = try await photosManager.downloadPhoto(photo: photo, quality: .fullResolution)
        } catch {
            throw WallpaperError.downloadFailed(error)
        }
        
        // Cache the image and get the local URL
        let imageURL: URL
        do {
            imageURL = try imageCacheService.cacheImage(for: photo, data: imageData)
        } catch {
            throw WallpaperError.cacheError(error)
        }
        
        // Apply wallpaper to all connected displays
        try await applyWallpaperToAllDisplays(imageURL: imageURL)
        
        // Update current photo
        await MainActor.run {
            self.currentPhoto = photo
        }
    }
    
    /// Applies the wallpaper image to all connected displays
    private func applyWallpaperToAllDisplays(imageURL: URL) async throws {
        let screens = NSScreen.screens
        
        guard !screens.isEmpty else {
            throw WallpaperError.noDisplaysAvailable
        }
        
        for screen in screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
            } catch {
                throw WallpaperError.setWallpaperFailed(error)
            }
        }
    }

    
    // MARK: - Rotation Control
    
    /// Starts wallpaper rotation with the given photos and interval
    /// - Parameters:
    ///   - photos: Array of photos to rotate through
    ///   - interval: Time interval between wallpaper changes in seconds
    func startRotation(photos: [Photo], interval: TimeInterval) {
        print("=== WallpaperManager: Starting rotation ===")
        print("Photos count: \(photos.count)")
        print("Interval: \(interval) seconds")

        guard !photos.isEmpty else {
            print("ERROR: No photos to rotate")
            return
        }

        // Stop any existing rotation
        stopRotationTimer()

        // Initialize rotation state
        rotationState = RotationState(
            isActive: true,
            isPaused: false,
            currentIndex: 0,
            photos: photos,
            interval: interval,
            lastRotationTime: Date()
        )

        isRotating = true
        isPaused = false

        print("First photo: \(photos[0].filename)")
        print("First photo baseUrl: \(photos[0].baseUrl)")

        // Set the first wallpaper immediately
        Task {
            await setCurrentWallpaper()
        }

        // Start the rotation timer
        startRotationTimer(interval: interval)
    }
    
    /// Pauses the wallpaper rotation, preserving the current state
    func pauseRotation() {
        guard isRotating, !isPaused else { return }
        
        stopRotationTimer()
        
        rotationState.isPaused = true
        isPaused = true
    }
    
    /// Resumes the wallpaper rotation from the current position
    func resumeRotation() {
        guard isRotating, isPaused else { return }
        
        rotationState.isPaused = false
        isPaused = false
        
        // Restart the timer
        startRotationTimer(interval: rotationState.interval)
    }
    
    /// Stops the wallpaper rotation completely
    func stopRotation() {
        stopRotationTimer()
        
        rotationState = RotationState(
            isActive: false,
            isPaused: false,
            currentIndex: 0,
            photos: [],
            interval: rotationState.interval,
            lastRotationTime: nil
        )
        
        isRotating = false
        isPaused = false
        currentPhoto = nil
    }
    
    // MARK: - Timer Management
    
    private func startRotationTimer(interval: TimeInterval) {
        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceToNextPhoto()
        }
        
        // Ensure timer runs on common run loop mode
        if let timer = rotationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }
    
    // MARK: - Photo Advancement
    
    private func advanceToNextPhoto() {
        guard !rotationState.photos.isEmpty else { return }
        
        rotationState.advanceToNext()
        
        Task {
            await setCurrentWallpaper()
        }
    }
    
    private func setCurrentWallpaper() async {
        print("=== WallpaperManager: setCurrentWallpaper called ===")

        guard let photo = rotationState.currentPhoto else {
            print("ERROR: No current photo in rotation state")
            return
        }

        print("Setting wallpaper to: \(photo.filename)")

        do {
            try await setWallpaper(photo: photo)
            print("SUCCESS: Wallpaper set successfully")
        } catch {
            // Log error but continue rotation
            print("ERROR: Failed to set wallpaper: \(error.localizedDescription)")
            if let wallpaperError = error as? WallpaperError {
                print("WallpaperError details: \(wallpaperError)")
            }
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopRotationTimer()
    }
}
