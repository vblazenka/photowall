# PhotoWall

A macOS menu bar application that automatically rotates your desktop wallpaper using photos from Google Photos.

## Features

- **Menu Bar Integration**: Runs quietly in your menu bar, always accessible
- **Google Photos Integration**: Select photos directly from your Google Photos using the official Picker API
- **Automatic Rotation**: Configurable intervals (1-60 minutes) for wallpaper changes
- **Multi-Display Support**: Automatically applies wallpapers across all connected displays
- **Smart Caching**: Locally caches full-resolution images for smooth rotation without re-downloading
- **Privacy-Focused**: Uses OAuth 2.0 with PKCE for secure authentication
- **Pause & Resume**: Control rotation on demand

## Requirements

- macOS 13.0 (Ventura) or later
- Google account with access to Google Photos

## Download

Available on the Mac App Store: [Link coming soon]

## Usage

1. **Sign In**: On first launch, click "Sign in with Google" and authorize the app
2. **Select Photos**: Click "Select Photos" to open the Google Photos Picker
3. **Choose Photos**: Select the photos you want to use for rotation
4. **Configure**: Set your preferred rotation interval in Settings
5. **Start Rotation**: Wallpapers will automatically rotate at your chosen interval
6. **Pause/Resume**: Use the menu bar icon to pause or resume rotation anytime

## Development

### Project Structure

```
PhotoWall/
├── Managers/           # Business logic coordinators
│   ├── AuthManager.swift
│   ├── PhotosManager.swift
│   ├── WallpaperManager.swift
│   └── SettingsManager.swift
├── Services/           # Infrastructure services
│   ├── KeychainService.swift
│   ├── PhotosPickerService.swift
│   └── ImageCacheService.swift
├── Models/             # Data models
├── Views/              # SwiftUI views
└── PhotoWallApp.swift  # App entry point
```

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme PhotoWall -testPlan PhotoWall

# Run specific test class
xcodebuild test -scheme PhotoWall -only-testing:PhotoWallTests/KeychainPropertyTests
```

### Architecture

PhotoWall follows a manager-based architecture:

- **Managers**: Handle core business logic (auth, photos, wallpaper rotation, settings)
- **Services**: Provide infrastructure capabilities (keychain, API communication, caching)
- **Views**: SwiftUI-based UI with dependency injection of managers

The app uses the Google Photos Picker API (not the deprecated Library API) for photo selection.

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **OAuth 2.0 with PKCE**: Secure authentication
- **Google Photos Picker API**: Official API for photo selection
- **Keychain Services**: Secure credential storage
- **SwiftCheck**: Property-based testing framework

## Privacy & Security

- **No Photo Storage**: Only photo metadata and cache URLs are stored locally
- **Keychain Storage**: OAuth credentials are securely stored in macOS Keychain
- **Limited Scope**: Only requests read-only access to photos you explicitly select
- **Local Caching**: Full-resolution images are cached locally for performance

## Troubleshooting

**"Invalid client" error during sign-in**
- Verify your `GOOGLE_CLIENT_ID` is correctly set in the Xcode scheme
- Ensure your OAuth consent screen includes the required scopes

**Wallpaper not changing**
- Check that rotation is not paused
- Verify photos were successfully selected from the picker
- Check Console.app for PhotoWall logs

**Photos appear stale or outdated**
- The picker cache is valid for 7 days
- Re-select photos using the "Select Photos" button to refresh

## License

Copyright © 2025. All rights reserved.

PhotoWall is proprietary software available for purchase on the Mac App Store. See LICENSE file for details.

## Support

For bug reports, feature requests, or support inquiries, please contact: contact@vedran.co

## Acknowledgments

- Built with SwiftUI for macOS
- Uses Google Photos Picker API
- Property-based testing with SwiftCheck
