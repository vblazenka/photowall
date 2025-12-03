import SwiftUI

/// Root content view that routes between SignInView and MainView based on auth state
/// Requirements: 1.4, 6.1, 6.2
struct ContentView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var photosManager: PhotosManager
    @ObservedObject var wallpaperManager: WallpaperManager
    
    init(
        authManager: AuthManager,
        settingsManager: SettingsManager,
        photosManager: PhotosManager,
        wallpaperManager: WallpaperManager
    ) {
        self.authManager = authManager
        self.settingsManager = settingsManager
        self.photosManager = photosManager
        self.wallpaperManager = wallpaperManager
    }
    
    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                // Loading state while checking existing auth
                loadingView
                    .transition(.opacity)
                
            case .signedOut:
                SignInView(authManager: authManager)
                    .transition(.opacity)
                
            case .signedIn:
                MainView(
                    authManager: authManager,
                    settingsManager: settingsManager,
                    wallpaperManager: wallpaperManager,
                    photosManager: photosManager
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .animation(Theme.Animation.standard, value: authManager.authState)
    }
    
    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            AnimatedProgressView()
                .scaleEffect(1.2)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview("Signed Out") {
    let authManager = AuthManager()
    let pickerService = PhotosPickerService(authManager: authManager)
    let photosManager = PhotosManager(authManager: authManager, pickerService: pickerService)

    return ContentView(
        authManager: authManager,
        settingsManager: SettingsManager(),
        photosManager: photosManager,
        wallpaperManager: WallpaperManager(photosManager: photosManager)
    )
    .frame(width: 320, height: 480)
}
