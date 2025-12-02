import Foundation

// MARK: - PhotosError

enum PhotosError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case downloadFailed(String)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in to access Google Photos."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Google Photos API"
        case .apiError(let message):
            return "API error: \(message)"
        case .downloadFailed(let message):
            return "Failed to download photo: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        }
    }
}

// MARK: - Google Photos API Response Models

struct AlbumsResponse: Codable {
    let albums: [AlbumResponse]?
    let nextPageToken: String?
}

struct AlbumResponse: Codable {
    let id: String
    let title: String?
    let productUrl: String?
    let coverPhotoBaseUrl: String?
    let coverPhotoMediaItemId: String?
    let mediaItemsCount: String?
    
    func toAlbum() -> Album {
        Album(
            id: id,
            title: title ?? "Untitled Album",
            coverPhotoBaseUrl: coverPhotoBaseUrl,
            mediaItemsCount: mediaItemsCount.flatMap { Int($0) },
            productUrl: productUrl
        )
    }
}

struct MediaItemsResponse: Codable {
    let mediaItems: [MediaItemResponse]?
    let nextPageToken: String?
}


struct MediaItemResponse: Codable {
    let id: String
    let baseUrl: String?
    let filename: String?
    let mimeType: String?
    let mediaMetadata: MediaMetadataResponse?
    let productUrl: String?
    
    func toPhoto() -> Photo? {
        guard let baseUrl = baseUrl else { return nil }
        return Photo(
            id: id,
            baseUrl: baseUrl,
            filename: filename ?? "unknown",
            mimeType: mimeType ?? "image/jpeg",
            mediaMetadata: mediaMetadata?.toMediaMetadata()
        )
    }
}

struct MediaMetadataResponse: Codable {
    let width: String?
    let height: String?
    let creationTime: String?
    let photo: PhotoMetadataResponse?
    let video: VideoMetadataResponse?
    
    func toMediaMetadata() -> MediaMetadata {
        MediaMetadata(
            width: width,
            height: height,
            creationTime: creationTime
        )
    }
}

struct PhotoMetadataResponse: Codable {
    let cameraMake: String?
    let cameraModel: String?
    let focalLength: Double?
    let apertureFNumber: Double?
    let isoEquivalent: Int?
}

struct VideoMetadataResponse: Codable {
    let cameraMake: String?
    let cameraModel: String?
    let fps: Double?
    let status: String?
}

struct SearchMediaItemsRequest: Codable {
    let albumId: String
    let pageSize: Int
    let pageToken: String?
}

// MARK: - PhotosManagerProtocol

protocol PhotosManagerProtocol {
    func fetchAlbums() async throws -> [Album]
    func fetchPhotos(albumId: String) async throws -> [Photo]
    func downloadPhoto(photo: Photo, quality: PhotoQuality) async throws -> Data
}

// MARK: - PhotosManager

final class PhotosManager: PhotosManagerProtocol, ObservableObject {
    
    // MARK: - Constants
    
    private enum Constants {
        static let baseURL = "https://photoslibrary.googleapis.com/v1"
        static let albumsEndpoint = "/albums"
        static let mediaItemsSearchEndpoint = "/mediaItems:search"
        static let defaultPageSize = 50
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 1.0
    }
    
    // MARK: - Properties
    
    private let authManager: any AuthManagerProtocol
    private let urlSession: URLSession
    private let imageCacheService: ImageCacheServiceProtocol
    
    // MARK: - Initialization
    
    init(
        authManager: any AuthManagerProtocol,
        urlSession: URLSession = .shared,
        imageCacheService: ImageCacheServiceProtocol = ImageCacheService()
    ) {
        self.authManager = authManager
        self.urlSession = urlSession
        self.imageCacheService = imageCacheService
    }
    
    // MARK: - Fetch Albums
    
    func fetchAlbums() async throws -> [Album] {
        var allAlbums: [Album] = []
        var nextPageToken: String? = nil
        
        repeat {
            let (albums, token) = try await fetchAlbumsPage(pageToken: nextPageToken)
            allAlbums.append(contentsOf: albums)
            nextPageToken = token
        } while nextPageToken != nil
        
        return allAlbums
    }
    
    private func fetchAlbumsPage(pageToken: String?) async throws -> ([Album], String?) {
        let accessToken = try await getAccessToken()
        
        var components = URLComponents(string: Constants.baseURL + Constants.albumsEndpoint)!
        var queryItems = [URLQueryItem(name: "pageSize", value: String(Constants.defaultPageSize))]
        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw PhotosError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Debug logging
        print("=== Albums API Request ===")
        print("URL: \(url)")
        print("Access Token (first 20 chars): \(String(accessToken.prefix(20)))...")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PhotosError.invalidResponse
        }

        // Debug logging for response
        print("=== Albums API Response ===")
        print("Status Code: \(httpResponse.statusCode)")
        if httpResponse.statusCode != 200 {
            print("Error Response Body: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
        }

        try handleHTTPResponse(httpResponse, data: data)

        let albumsResponse = try JSONDecoder().decode(AlbumsResponse.self, from: data)
        let albums = albumsResponse.albums?.map { $0.toAlbum() } ?? []
        
        return (albums, albumsResponse.nextPageToken)
    }

    
    // MARK: - Fetch Photos
    
    func fetchPhotos(albumId: String) async throws -> [Photo] {
        var allPhotos: [Photo] = []
        var nextPageToken: String? = nil
        
        repeat {
            let (photos, token) = try await fetchPhotosPage(albumId: albumId, pageToken: nextPageToken)
            allPhotos.append(contentsOf: photos)
            nextPageToken = token
        } while nextPageToken != nil
        
        return allPhotos
    }
    
    private func fetchPhotosPage(albumId: String, pageToken: String?) async throws -> ([Photo], String?) {
        let accessToken = try await getAccessToken()
        
        guard let url = URL(string: Constants.baseURL + Constants.mediaItemsSearchEndpoint) else {
            throw PhotosError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let searchRequest = SearchMediaItemsRequest(
            albumId: albumId,
            pageSize: Constants.defaultPageSize,
            pageToken: pageToken
        )
        request.httpBody = try JSONEncoder().encode(searchRequest)
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PhotosError.invalidResponse
        }
        
        try handleHTTPResponse(httpResponse, data: data)
        
        let mediaItemsResponse = try JSONDecoder().decode(MediaItemsResponse.self, from: data)
        let photos = mediaItemsResponse.mediaItems?.compactMap { $0.toPhoto() } ?? []
        
        return (photos, mediaItemsResponse.nextPageToken)
    }
    
    // MARK: - Download Photo
    
    func downloadPhoto(photo: Photo, quality: PhotoQuality) async throws -> Data {
        // Check cache first for full resolution images
        if quality == .fullResolution, let cachedURL = imageCacheService.getCachedImage(for: photo) {
            if let data = try? Data(contentsOf: cachedURL) {
                return data
            }
        }
        
        let imageURL: String
        switch quality {
        case .thumbnail:
            imageURL = photo.thumbnailUrl
        case .fullResolution:
            imageURL = photo.fullResolutionUrl
        }
        
        guard let url = URL(string: imageURL) else {
            throw PhotosError.downloadFailed("Invalid image URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PhotosError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PhotosError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }
        
        // Cache full resolution images
        if quality == .fullResolution {
            _ = try? imageCacheService.cacheImage(for: photo, data: data)
        }
        
        return data
    }
    
    // MARK: - Helper Methods
    
    private func getAccessToken() async throws -> String {
        guard await authManager.isAuthenticated else {
            throw PhotosError.notAuthenticated
        }
        
        do {
            return try await authManager.refreshTokenIfNeeded()
        } catch {
            throw PhotosError.notAuthenticated
        }
    }
    
    private func performRequest(_ request: URLRequest, retryCount: Int = 0) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch {
            if retryCount < Constants.maxRetries {
                try await Task.sleep(nanoseconds: UInt64(Constants.retryDelay * Double(retryCount + 1) * 1_000_000_000))
                return try await performRequest(request, retryCount: retryCount + 1)
            }
            throw PhotosError.networkError(error)
        }
    }
    
    private func handleHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw PhotosError.notAuthenticated
        case 429:
            throw PhotosError.rateLimitExceeded
        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PhotosError.apiError("HTTP \(response.statusCode): \(errorMessage)")
        }
    }
}
