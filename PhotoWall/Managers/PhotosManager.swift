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

// MARK: - PhotosManagerProtocol

protocol PhotosManagerProtocol {
    func createPickerSession(maxItemCount: Int?) async throws -> PickerSessionResponse
    func getPickerSession(sessionId: String) async throws -> PickerSessionResponse
    func fetchPhotosFromPicker(sessionId: String) async throws -> [Photo]
    func downloadPhoto(photo: Photo, quality: PhotoQuality) async throws -> Data
}

// MARK: - PhotosManager

final class PhotosManager: PhotosManagerProtocol, ObservableObject {

    // MARK: - Constants

    private enum Constants {
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 1.0
    }

    // MARK: - Properties

    private let authManager: any AuthManagerProtocol
    private let pickerService: PhotosPickerServiceProtocol
    private let urlSession: URLSession
    private let imageCacheService: ImageCacheServiceProtocol

    // MARK: - Initialization

    init(
        authManager: any AuthManagerProtocol,
        pickerService: PhotosPickerServiceProtocol,
        urlSession: URLSession = .shared,
        imageCacheService: ImageCacheServiceProtocol = ImageCacheService()
    ) {
        self.authManager = authManager
        self.pickerService = pickerService
        self.urlSession = urlSession
        self.imageCacheService = imageCacheService
    }
    
    // MARK: - Picker Integration

    func createPickerSession(maxItemCount: Int? = nil) async throws -> PickerSessionResponse {
        return try await pickerService.createPickerSession(maxItemCount: maxItemCount)
    }

    func getPickerSession(sessionId: String) async throws -> PickerSessionResponse {
        return try await pickerService.getSession(sessionId: sessionId)
    }

    func fetchPhotosFromPicker(sessionId: String) async throws -> [Photo] {
        return try await pickerService.fetchMediaItems(sessionId: sessionId)
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

        // Get access token for authenticated download (required by Picker API)
        let accessToken = try await getAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        print("=== Downloading Photo ===")
        print("URL: \(url.absoluteString)")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PhotosError.invalidResponse
        }

        print("Download Response Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("Download failed with status \(httpResponse.statusCode)")
            throw PhotosError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        print("Successfully downloaded \(data.count) bytes")

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
