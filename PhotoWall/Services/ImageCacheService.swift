import Foundation

// MARK: - ImageCacheError

enum ImageCacheError: Error, LocalizedError {
    case cacheDirectoryCreationFailed
    case writeFailed(Error)
    case readFailed(Error)
    case deleteFailed(Error)
    case invalidPhotoId
    
    var errorDescription: String? {
        switch self {
        case .cacheDirectoryCreationFailed:
            return "Failed to create cache directory"
        case .writeFailed(let error):
            return "Failed to write image to cache: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Failed to read image from cache: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete cache: \(error.localizedDescription)"
        case .invalidPhotoId:
            return "Invalid photo ID"
        }
    }
}

// MARK: - ImageCacheServiceProtocol

protocol ImageCacheServiceProtocol {
    func cacheImage(for photo: Photo, data: Data) throws -> URL
    func getCachedImage(for photo: Photo) -> URL?
    func clearCache() throws
    func cacheSize() -> Int64
}

// MARK: - ImageCacheService

final class ImageCacheService: ImageCacheServiceProtocol {
    
    private let fileManager: FileManager
    private let cacheDirectoryName: String
    
    private var cacheDirectory: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("PhotoWall").appendingPathComponent(cacheDirectoryName)
    }

    
    init(fileManager: FileManager = .default, cacheDirectoryName: String = "ImageCache") {
        self.fileManager = fileManager
        self.cacheDirectoryName = cacheDirectoryName
    }
    
    // MARK: - Cache Directory Management
    
    private func ensureCacheDirectoryExists() throws -> URL {
        guard let cacheDir = cacheDirectory else {
            throw ImageCacheError.cacheDirectoryCreationFailed
        }
        
        if !fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw ImageCacheError.cacheDirectoryCreationFailed
            }
        }
        
        return cacheDir
    }
    
    private func cacheFilePath(for photo: Photo) throws -> URL {
        let cacheDir = try ensureCacheDirectoryExists()
        let sanitizedId = photo.id.replacingOccurrences(of: "/", with: "_")
        return cacheDir.appendingPathComponent(sanitizedId)
    }
    
    // MARK: - ImageCacheServiceProtocol
    
    func cacheImage(for photo: Photo, data: Data) throws -> URL {
        guard !photo.id.isEmpty else {
            throw ImageCacheError.invalidPhotoId
        }
        
        let filePath = try cacheFilePath(for: photo)
        
        do {
            try data.write(to: filePath, options: .atomic)
            return filePath
        } catch {
            throw ImageCacheError.writeFailed(error)
        }
    }
    
    func getCachedImage(for photo: Photo) -> URL? {
        guard let filePath = try? cacheFilePath(for: photo),
              fileManager.fileExists(atPath: filePath.path) else {
            return nil
        }
        return filePath
    }
    
    func clearCache() throws {
        guard let cacheDir = cacheDirectory else {
            return
        }
        
        guard fileManager.fileExists(atPath: cacheDir.path) else {
            return
        }
        
        do {
            try fileManager.removeItem(at: cacheDir)
        } catch {
            throw ImageCacheError.deleteFailed(error)
        }
    }
    
    func cacheSize() -> Int64 {
        guard let cacheDir = cacheDirectory,
              fileManager.fileExists(atPath: cacheDir.path) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
}
