import Foundation

// MARK: - Album

struct Album: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let coverPhotoBaseUrl: String?
    let mediaItemsCount: Int?
    let productUrl: String?
}

// MARK: - Photo

struct Photo: Identifiable, Codable, Equatable {
    let id: String
    let baseUrl: String
    let filename: String
    let mimeType: String
    let mediaMetadata: MediaMetadata?
    
    var thumbnailUrl: String {
        "\(baseUrl)=w200-h200-c"
    }
    
    var fullResolutionUrl: String {
        "\(baseUrl)=d"
    }
}

// MARK: - MediaMetadata

struct MediaMetadata: Codable, Equatable {
    let width: String?
    let height: String?
    let creationTime: String?
}

// MARK: - PickerCache

struct PickerCache: Codable, Equatable {
    let photos: [Photo]
    let selectionDate: Date

    var isStale: Bool {
        Date().timeIntervalSince(selectionDate) > 604800 // 7 days
    }
}

// MARK: - OAuthCredentials

struct OAuthCredentials: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
}

// MARK: - RotationState

struct RotationState: Equatable {
    var isActive: Bool
    var isPaused: Bool
    var currentIndex: Int
    var photos: [Photo]
    var interval: TimeInterval
    var lastRotationTime: Date?

    
    /// Advances to the next photo in the rotation queue (circular)
    mutating func advanceToNext() {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex + 1) % photos.count
        lastRotationTime = Date()
    }
    
    var currentPhoto: Photo? {
        guard !photos.isEmpty, currentIndex >= 0, currentIndex < photos.count else {
            return nil
        }
        return photos[currentIndex]
    }
}

// MARK: - AuthState

enum AuthState: Equatable {
    case unknown
    case signedOut
    case signedIn(user: UserInfo)
}

// MARK: - UserInfo

struct UserInfo: Codable, Equatable {
    let email: String
    let name: String?
    let pictureUrl: String?
}

// MARK: - ViewState

enum ViewState: Equatable {
    case signIn
    case main
    case albums
    case photos(album: Album)
    case settings
}

// MARK: - PhotoQuality

enum PhotoQuality {
    case thumbnail
    case fullResolution
}
