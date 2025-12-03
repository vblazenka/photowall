# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PhotoWall is a macOS menu bar application that automatically rotates wallpapers from Google Photos albums. Built with SwiftUI and targeting macOS 13.0+, it runs as a status bar utility with OAuth 2.0 authentication, local image caching, and multi-display support.

## Build and Development Commands

### Building the App
```bash
# Build the app using xcodebuild
xcodebuild -scheme PhotoWall -configuration Debug build

# Build for Release
xcodebuild -scheme PhotoWall -configuration Release build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -scheme PhotoWall -testPlan PhotoWall

# Run a specific test class
xcodebuild test -scheme PhotoWall -only-testing:PhotoWallTests/KeychainPropertyTests

# Run a specific test method
xcodebuild test -scheme PhotoWall -only-testing:PhotoWallTests/KeychainPropertyTests/testSaveAndLoadCredentials
```

### Opening the Project
```bash
# Open in Xcode
open PhotoWall.xcodeproj
```

## Architecture Overview

### Manager Layer (Core Business Logic)
The app follows a manager-based architecture where managers are instantiated once at app launch and injected into views:

- **AuthManager**: Handles OAuth 2.0 flow with Google using PKCE. Stores credentials in Keychain via KeychainService. Automatically checks existing auth on launch and refreshes expired tokens. Includes automatic migration from deprecated `photoslibrary.readonly` scope to `photospicker.mediaitems.readonly`.
- **PhotosManager**: Interfaces with Google Photos Picker API via PhotosPickerService. Creates picker sessions and fetches selected media items. Uses ImageCacheService for full-resolution downloads. No longer directly fetches albums or photos - user selection is required via picker.
- **WallpaperManager**: Controls wallpaper rotation lifecycle (start/pause/resume/stop). Maintains RotationState (photos queue, current index, interval). Applies wallpapers to all connected displays via NSWorkspace. Monitors display connection changes and reapplies wallpaper to newly connected displays.
- **SettingsManager**: Persists user preferences to UserDefaults (rotation interval, picker cache, selected photos, pause state). Caches full Photo objects from picker selections with 7-day staleness threshold. Provides methods for caching and retrieving selected photos.

### Service Layer (Infrastructure)
- **KeychainService**: Secure storage for OAuth credentials using Security framework
- **PhotosPickerService**: Handles Google Photos Picker API communication. Creates picker sessions and fetches media items from completed selections. Supports pagination and converts picker responses to Photo models.
- **ImageCacheService**: Caches full-resolution images in Application Support directory. Generates cache file paths using sanitized photo IDs. Provides cache size calculation and clearing functionality.

### App Lifecycle
The AppDelegate pattern is used (not Scene-based):
1. `PhotoWallApp` registers an `AppDelegate` via `@NSApplicationDelegateAdaptor`
2. In `applicationDidFinishLaunching`, the AppDelegate:
   - Instantiates all managers (AuthManager → PhotosPickerService → PhotosManager → WallpaperManager)
   - Creates status bar item with menu bar icon
   - Sets up NSPopover with ContentView (injecting all managers)
   - Monitors display connection changes via NSApplication.didChangeScreenParametersNotification
3. ContentView routes between SignInView and MainView based on AuthManager.authState
4. Managers are shared across the app through dependency injection, not SwiftUI environment

### View Hierarchy
```
ContentView (routes on auth state)
├─ SignInView (authState == .signedOut)
└─ MainView (authState == .signedIn)
   ├─ AlbumsView (launch picker, view selection status)
   │  └─ PickerSheetView (modal picker flow)
   │     └─ PickerWebView (embeds Google's picker UI)
   └─ SettingsView (configure rotation interval, control rotation, view picker cache info)
```

### OAuth Configuration
The app requires `GOOGLE_CLIENT_ID` environment variable set in the Xcode scheme. The current scheme includes:
```
GOOGLE_CLIENT_ID=59012961394-f95l5hk5up0e4hlma90hk2gjii3suvi2.apps.googleusercontent.com
```

OAuth flow uses:
- Authorization endpoint: `https://accounts.google.com/o/oauth2/v2/auth`
- Token endpoint: `https://oauth2.googleapis.com/token`
- Scopes: `photospicker.mediaitems.readonly`, `openid`, `email`, `profile`
- PKCE for secure authorization
- Custom URL scheme: `com.photowall.app:/oauth2callback`

**Note**: The app uses the Google Photos Picker API (not the deprecated Library API). The `photoslibrary.readonly` scope was removed on March 31, 2025.

### Testing Strategy
The test suite uses property-based testing with SwiftCheck library:
- **TestGenerators.swift**: Contains Arbitrary implementations for all model types (OAuthCredentials, Photo, Album, RotationState, etc.)
- Property tests verify invariants across randomized inputs:
  - KeychainPropertyTests: Keychain save/load/delete operations
  - AuthPropertyTests: OAuth credential handling
  - ImageCachePropertyTests: Image caching behavior
  - RotationPropertyTests: Wallpaper rotation state transitions
  - SelectionPropertyTests: Photo/album selection logic
  - SettingsPropertyTests: UserDefaults persistence

### Data Models (Models.swift)
- **Album**: Google Photos album metadata (id, title, cover photo, item count) - *Note: No longer fetched directly, preserved for compatibility*
- **Photo**: Photo metadata with baseUrl property used to construct download URLs (`baseUrl + "=w200-h200-c"` for thumbnails, `baseUrl + "=d"` for full resolution)
- **PickerCache**: Stores cached photos from picker selections with selectionDate. Has `isStale` computed property (7-day threshold).
- **OAuthCredentials**: Access token, refresh token, expiration date
- **RotationState**: Maintains rotation queue, current index, and provides `advanceToNext()` for circular iteration
- **AuthState**: Enum with .unknown (checking), .signedOut, .signedIn(UserInfo)

### Picker API Models (PickerModels.swift)
- **PickerSessionRequest/Response**: Models for creating picker sessions
- **PickerMediaItemsResponse**: Response from fetching media items from a picker session
- **PickerMediaItem**: Individual media item with conversion to Photo model via `toPhoto()`
- **PickerError**: Typed errors for picker operations

### Key Implementation Details

**Multi-Display Support**: WallpaperManager.setWallpaper() iterates through NSScreen.screens and calls NSWorkspace.shared.setDesktopImageURL() for each. Display changes are detected via NSApplication.didChangeScreenParametersNotification, and the current wallpaper is reapplied to all displays (including newly connected ones).

**Image Caching Strategy**: PhotosManager downloads photos on-demand. Full-resolution images are cached by ImageCacheService in `~/Library/Application Support/PhotoWall/ImageCache/`. Cache keys are photo IDs with "/" replaced by "_". Wallpapers are set from cached file URLs, not in-memory data.

**Picker API Architecture**: The app uses Google Photos Picker API instead of the deprecated Library API. User flow:
1. User clicks "Select Photos" in AlbumsView
2. PhotosPickerService creates a picker session via `POST /v1/sessions`
3. PickerWebView (WKWebView) loads Google's picker UI from session.pickerUri
4. User selects photos in Google's UI
5. On completion, app fetches selected media items via `GET /v1/{mediaItemsSetId}/mediaItems`
6. Photos are cached in SettingsManager.pickerCache (includes full Photo objects)
7. Cached photos are used for rotation without re-prompting user
8. Cache is valid for 7 days, after which staleness warning is shown

**Picker Cache Strategy**: Full Photo objects (including baseUrl) are cached in UserDefaults as JSON. This is necessary because:
- Picker requires user interaction (can't auto-refresh programmatically)
- BaseUrl URLs remain valid for extended periods
- Enables wallpaper rotation without repeated picker prompts
- When cache becomes stale (7+ days), user is prompted to re-select

**Error Handling**: Managers use typed error enums (AuthError, PhotosError, PickerError, WallpaperError, KeychainError, ImageCacheError) with LocalizedError conformance. Network requests in PhotosManager and PhotosPickerService include retry logic (max 3 retries with exponential backoff).

**State Persistence**: On app quit, AppDelegate.saveCurrentState() persists pause state via SettingsManager. WallpaperManager.stopRotation() is called to clean up timers. UserDefaults.standard.synchronize() ensures persistence.

## Common Patterns

### Adding a New Manager
1. Define a protocol with `@MainActor` if needed (e.g., AuthManagerProtocol)
2. Implement the manager class conforming to the protocol and ObservableObject
3. Initialize in AppDelegate.setupManagers()
4. Inject into ContentView in AppDelegate.setupMenuBar()
5. Pass down through view hierarchy via initializers (not environment)

### Adding a New View
1. Create view in PhotoWall/Views/
2. Inject required managers via initializer (e.g., `init(authManager: AuthManager, ...)`)
3. Declare managers as @ObservedObject properties
4. Add navigation logic in MainView

### Adding Property Tests
1. Add Arbitrary conformance for new model types in TestGenerators.swift
2. Use Gen.compose for complex types, Gen.fromElements for enums/fixed values
3. Create test file in PhotoWallTests/PropertyTests/
4. Use SwiftCheck's `property` function to verify invariants

## Dependencies

- **SwiftCheck** (via Swift Package Manager): Property-based testing framework
  - Repository: https://github.com/typelift/SwiftCheck.git
  - Version: 0.12.0+
  - Used only in test target

## Project Structure

```
PhotoWall/
├── Managers/          # Business logic coordinators
├── Services/          # Infrastructure services
├── Models/            # Data models (single Models.swift file)
├── Views/             # SwiftUI views
├── Theme/             # UI theming (Theme.swift)
├── PhotoWallApp.swift # App entry point with AppDelegate
└── ContentView.swift  # Root view with auth routing

PhotoWallTests/
├── PropertyTests/     # Property-based tests
└── TestGenerators.swift # Arbitrary implementations for models
```

## Google Cloud Console Setup

Before running the app, ensure your Google Cloud Console project is configured correctly:

### Required OAuth Scope

The OAuth consent screen must include:
```
https://www.googleapis.com/auth/photospicker.mediaitems.readonly
```

**Important**: The old `photoslibrary.readonly` scope was deprecated and removed on March 31, 2025. If your project still has this scope, remove it and add the picker scope instead.

### Setup Steps

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to: APIs & Services → OAuth consent screen
3. Click "Edit App"
4. In the "Scopes" section:
   - Remove `photoslibrary.readonly` if present
   - Add `photospicker.mediaitems.readonly`
   - Keep `openid`, `email`, and `profile`
5. Save changes

**Note**: Scope changes may take several hours to propagate. Test users may need to be re-authorized after the change.

### Automatic Migration

The app includes automatic migration logic in AuthManager that:
- Detects old credentials with deprecated scope on first launch
- Clears them from Keychain
- Forces user to re-authenticate with new scope
- Sets a UserDefaults flag to prevent re-migration

This ensures a smooth transition for existing users.
