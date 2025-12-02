import Foundation
import SwiftCheck
@testable import PhotoWall

// MARK: - OAuthCredentials Generator

extension OAuthCredentials: Arbitrary {
    public static var arbitrary: Gen<OAuthCredentials> {
        Gen<OAuthCredentials>.compose { c in
            OAuthCredentials(
                accessToken: c.generate(using: tokenGenerator),
                refreshToken: c.generate(using: tokenGenerator),
                expiresAt: c.generate(using: dateGenerator)
            )
        }
    }
    
    private static var tokenGenerator: Gen<String> {
        Gen<String>.compose { c in
            let length = c.generate(using: Gen<Int>.fromElements(in: 20...100))
            let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
            return String((0..<length).map { _ in chars.randomElement()! })
        }
    }
    
    private static var dateGenerator: Gen<Date> {
        Gen<Date>.compose { c in
            let offset = c.generate(using: Gen<Int>.fromElements(in: -86400...86400))
            return Date().addingTimeInterval(TimeInterval(offset))
        }
    }
}

// MARK: - MediaMetadata Generator

extension MediaMetadata: Arbitrary {
    public static var arbitrary: Gen<MediaMetadata> {
        Gen<MediaMetadata>.compose { c in
            MediaMetadata(
                width: c.generate(using: optionalDimensionGenerator),
                height: c.generate(using: optionalDimensionGenerator),
                creationTime: c.generate(using: optionalDateStringGenerator)
            )
        }
    }
    
    private static var optionalDimensionGenerator: Gen<String?> {
        Gen<String?>.frequency([
            (1, Gen<String?>.pure(nil)),
            (3, Gen<Int>.fromElements(in: 100...8000).map { String($0) as String? })
        ])
    }

    
    private static var optionalDateStringGenerator: Gen<String?> {
        Gen<String?>.frequency([
            (1, Gen<String?>.pure(nil)),
            (3, Gen<String?>.pure(ISO8601DateFormatter().string(from: Date())))
        ])
    }
}

// MARK: - Photo Generator

extension Photo: Arbitrary {
    public static var arbitrary: Gen<Photo> {
        Gen<Photo>.compose { c in
            Photo(
                id: c.generate(using: idGenerator),
                baseUrl: c.generate(using: baseUrlGenerator),
                filename: c.generate(using: filenameGenerator),
                mimeType: c.generate(using: mimeTypeGenerator),
                mediaMetadata: c.generate()
            )
        }
    }
    
    private static var idGenerator: Gen<String> {
        Gen<String>.compose { c in
            let length = c.generate(using: Gen<Int>.fromElements(in: 20...50))
            let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            return String((0..<length).map { _ in chars.randomElement()! })
        }
    }
    
    private static var baseUrlGenerator: Gen<String> {
        Gen.pure("https://lh3.googleusercontent.com/").map { base in
            let suffix = String((0..<40).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
            return base + suffix
        }
    }
    
    private static var filenameGenerator: Gen<String> {
        Gen<String>.compose { c in
            let name = String((0..<10).map { _ in "abcdefghijklmnopqrstuvwxyz".randomElement()! })
            let ext = c.generate(using: Gen<String>.fromElements(of: ["jpg", "jpeg", "png", "heic"]))
            return "\(name).\(ext)"
        }
    }
    
    private static var mimeTypeGenerator: Gen<String> {
        Gen<String>.fromElements(of: ["image/jpeg", "image/png", "image/heic"])
    }
}

// MARK: - Album Generator

extension Album: Arbitrary {
    public static var arbitrary: Gen<Album> {
        Gen<Album>.compose { c in
            Album(
                id: c.generate(using: albumIdGenerator),
                title: c.generate(using: titleGenerator),
                coverPhotoBaseUrl: c.generate(using: optionalUrlGenerator),
                mediaItemsCount: c.generate(using: optionalCountGenerator),
                productUrl: c.generate(using: optionalUrlGenerator)
            )
        }
    }
    
    private static var albumIdGenerator: Gen<String> {
        Gen<String>.compose { _ in
            let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            return String((0..<30).map { _ in chars.randomElement()! })
        }
    }
    
    private static var titleGenerator: Gen<String> {
        Gen<String>.fromElements(of: [
            "Vacation 2024", "Family Photos", "Nature", "Landscapes",
            "Portraits", "Travel", "Events", "Screenshots", "Downloads"
        ])
    }
    
    private static var optionalUrlGenerator: Gen<String?> {
        Gen<String?>.frequency([
            (1, Gen<String?>.pure(nil)),
            (3, Gen.pure("https://photos.google.com/").map { base -> String? in
                let suffix = String((0..<20).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
                return base + suffix
            })
        ])
    }
    
    private static var optionalCountGenerator: Gen<Int?> {
        Gen<Int?>.frequency([
            (1, Gen<Int?>.pure(nil)),
            (3, Gen<Int>.fromElements(in: 0...1000).map { $0 as Int? })
        ])
    }
}


// MARK: - RotationState Generator

extension RotationState: Arbitrary {
    public static var arbitrary: Gen<RotationState> {
        Gen<RotationState>.compose { c in
            let photos: [Photo] = c.generate()
            let photoCount = photos.count
            let currentIndex = photoCount > 0 ? c.generate(using: Gen<Int>.fromElements(in: 0...max(0, photoCount - 1))) : 0
            
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
    
    private static var intervalGenerator: Gen<TimeInterval> {
        Gen<TimeInterval>.fromElements(of: [
            300,    // 5 minutes
            900,    // 15 minutes
            1800,   // 30 minutes
            3600,   // 1 hour
            86400   // 1 day
        ])
    }
    
    private static var optionalDateGenerator: Gen<Date?> {
        Gen<Date?>.frequency([
            (1, Gen<Date?>.pure(nil)),
            (3, Gen<Date?>.pure(Date()))
        ])
    }
}

// MARK: - UserInfo Generator

extension UserInfo: Arbitrary {
    public static var arbitrary: Gen<UserInfo> {
        Gen<UserInfo>.compose { c in
            UserInfo(
                email: c.generate(using: emailGenerator),
                name: c.generate(using: optionalNameGenerator),
                pictureUrl: c.generate(using: optionalPictureUrlGenerator)
            )
        }
    }
    
    private static var emailGenerator: Gen<String> {
        Gen<String>.compose { _ in
            let name = String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyz".randomElement()! })
            let domain = ["gmail.com", "example.com", "test.com"].randomElement()!
            return "\(name)@\(domain)"
        }
    }
    
    private static var optionalNameGenerator: Gen<String?> {
        Gen<String?>.frequency([
            (1, Gen<String?>.pure(nil)),
            (3, Gen<String>.fromElements(of: ["John Doe", "Jane Smith", "Test User", "Alice Bob"]).map { $0 as String? })
        ])
    }
    
    private static var optionalPictureUrlGenerator: Gen<String?> {
        Gen<String?>.frequency([
            (1, Gen<String?>.pure(nil)),
            (3, Gen.pure("https://lh3.googleusercontent.com/a/").map { base -> String? in
                let suffix = String((0..<20).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
                return base + suffix
            })
        ])
    }
}
