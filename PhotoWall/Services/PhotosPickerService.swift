import Foundation

// MARK: - Protocol

protocol PhotosPickerServiceProtocol {
    func createPickerSession(maxItemCount: Int?) async throws -> PickerSessionResponse
    func getSession(sessionId: String) async throws -> PickerSessionResponse
    func fetchMediaItems(sessionId: String) async throws -> [Photo]
}

// MARK: - PhotosPickerService

final class PhotosPickerService: PhotosPickerServiceProtocol {

    // MARK: - Constants

    private enum Constants {
        static let baseURL = "https://photospicker.googleapis.com/v1"
        static let sessionsEndpoint = "/sessions"
        static let defaultPageSize = 100
        static let maxRetries = 3
    }

    // MARK: - Properties

    private let authManager: any AuthManagerProtocol

    // MARK: - Initialization

    init(authManager: any AuthManagerProtocol) {
        self.authManager = authManager
    }

    // MARK: - Create Picker Session

    func createPickerSession(maxItemCount: Int? = nil) async throws -> PickerSessionResponse {
        let accessToken = try await getAccessToken()

        guard let url = URL(string: Constants.baseURL + Constants.sessionsEndpoint) else {
            throw PickerError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let sessionRequest = PickerSessionRequest(maxItemCount: maxItemCount)
        request.httpBody = try JSONEncoder().encode(sessionRequest)

        // Debug logging
        print("=== Picker Session Creation ===")
        print("URL: \(url)")
        print("Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "nil")")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickerError.invalidResponse
        }

        print("Response Status: \(httpResponse.statusCode)")
        print("Response Body: \(String(data: data, encoding: .utf8) ?? "nil")")

        try handleHTTPResponse(httpResponse, data: data)

        let sessionResponse = try JSONDecoder().decode(PickerSessionResponse.self, from: data)
        return sessionResponse
    }

    // MARK: - Get Session

    func getSession(sessionId: String) async throws -> PickerSessionResponse {
        let accessToken = try await getAccessToken()

        guard let url = URL(string: "\(Constants.baseURL)/sessions/\(sessionId)") else {
            throw PickerError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Debug logging
        print("=== Picker Session Get ===")
        print("URL: \(url)")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickerError.invalidResponse
        }

        print("Response Status: \(httpResponse.statusCode)")
        print("Response Body: \(String(data: data, encoding: .utf8) ?? "nil")")

        if httpResponse.statusCode == 404 {
            throw PickerError.sessionExpired
        }

        try handleHTTPResponse(httpResponse, data: data)

        let sessionResponse = try JSONDecoder().decode(PickerSessionResponse.self, from: data)
        return sessionResponse
    }

    // MARK: - Fetch Media Items

    func fetchMediaItems(sessionId: String) async throws -> [Photo] {
        var allPhotos: [Photo] = []
        var nextPageToken: String? = nil

        repeat {
            let (photos, token) = try await fetchMediaItemsPage(
                sessionId: sessionId,
                pageToken: nextPageToken
            )
            allPhotos.append(contentsOf: photos)
            nextPageToken = token
        } while nextPageToken != nil

        return allPhotos
    }

    private func fetchMediaItemsPage(
        sessionId: String,
        pageToken: String?
    ) async throws -> ([Photo], String?) {
        let accessToken = try await getAccessToken()

        var components = URLComponents(string: "\(Constants.baseURL)/mediaItems")!
        var queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId),
            URLQueryItem(name: "pageSize", value: String(Constants.defaultPageSize))
        ]
        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw PickerError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Debug logging
        print("=== Fetching Media Items ===")
        print("URL: \(url)")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickerError.invalidResponse
        }

        print("Response Status: \(httpResponse.statusCode)")
        print("Response Body: \(String(data: data, encoding: .utf8) ?? "nil")")

        // Check for session expiration
        if httpResponse.statusCode == 404 {
            throw PickerError.sessionExpired
        }

        try handleHTTPResponse(httpResponse, data: data)

        let mediaItemsResponse = try JSONDecoder().decode(PickerMediaItemsResponse.self, from: data)
        let photos = mediaItemsResponse.mediaItems?.compactMap { $0.toPhoto() } ?? []

        print("Decoded \(mediaItemsResponse.mediaItems?.count ?? 0) media items")
        print("Converted to \(photos.count) photos")

        return (photos, mediaItemsResponse.nextPageToken)
    }

    // MARK: - Helper Methods

    private func getAccessToken() async throws -> String {
        return try await authManager.refreshTokenIfNeeded()
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 1...Constants.maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                return (data, response)
            } catch {
                lastError = error
                if attempt < Constants.maxRetries {
                    // Exponential backoff
                    let delay = TimeInterval(pow(2.0, Double(attempt)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? PickerError.mediaItemsFetchFailed
    }

    private func handleHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw PickerError.sessionExpired
        case 404:
            throw PickerError.sessionExpired
        default:
            // Try to decode error message
            if let errorString = String(data: data, encoding: .utf8) {
                print("Picker API error (\(response.statusCode)): \(errorString)")
            }
            throw PickerError.mediaItemsFetchFailed
        }
    }
}
