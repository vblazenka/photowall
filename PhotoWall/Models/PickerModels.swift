import Foundation

// MARK: - Picker Session Request/Response

/// Request to create a new picker session
struct PickerSessionRequest: Codable {
    let pickingConfig: PickingConfig?

    struct PickingConfig: Codable {
        let maxItemCount: String
    }

    init(maxItemCount: Int? = nil) {
        if let maxItemCount = maxItemCount {
            // Convert to string as required by API (int64 format)
            self.pickingConfig = PickingConfig(maxItemCount: String(maxItemCount))
        } else {
            // Omit pickingConfig to use default (2000 items)
            self.pickingConfig = nil
        }
    }
}

/// Response from creating or getting a picker session
struct PickerSessionResponse: Codable {
    let id: String
    let pickerUri: String?  // Only present on create, not on get
    let mediaItemsSet: Bool?
}

// MARK: - Picker Media Items Response

/// Response from fetching media items from a picker session
struct PickerMediaItemsResponse: Codable {
    let mediaItems: [PickerMediaItem]?
    let nextPageToken: String?
}

/// Individual media item from picker
struct PickerMediaItem: Codable {
    let id: String
    let createTime: String?
    let type: String?
    let mediaFile: MediaFile

    struct MediaFile: Codable {
        let baseUrl: String
        let mimeType: String?
        let filename: String?
        let mediaFileMetadata: MediaFileMetadata?

        struct MediaFileMetadata: Codable {
            let width: Int?
            let height: Int?
        }
    }
}

// MARK: - Conversion to Photo Model

extension PickerMediaItem {
    /// Convert PickerMediaItem to the app's Photo model
    func toPhoto() -> Photo? {
        // Require baseUrl to create a Photo
        guard !mediaFile.baseUrl.isEmpty else {
            return nil
        }

        return Photo(
            id: id,
            baseUrl: mediaFile.baseUrl,
            filename: mediaFile.filename ?? "Unknown",
            mimeType: mediaFile.mimeType ?? "image/jpeg",
            mediaMetadata: mediaFile.mediaFileMetadata.map { metadata in
                MediaMetadata(
                    width: metadata.width.map { String($0) },
                    height: metadata.height.map { String($0) },
                    creationTime: createTime
                )
            }
        )
    }
}

// MARK: - Picker Errors

enum PickerError: Error, LocalizedError {
    case sessionCreationFailed
    case sessionExpired
    case mediaItemsFetchFailed
    case invalidResponse
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .sessionCreationFailed:
            return "Failed to create picker session"
        case .sessionExpired:
            return "Picker session has expired"
        case .mediaItemsFetchFailed:
            return "Failed to fetch media items from picker"
        case .invalidResponse:
            return "Invalid response from picker API"
        case .userCancelled:
            return "User cancelled photo selection"
        }
    }
}
