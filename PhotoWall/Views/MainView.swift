import SwiftUI

/// Navigation tab enum for main interface
enum MainTab: String, CaseIterable {
    case albums = "Albums"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .albums: return "photo.on.rectangle.angled"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Main view displayed when user is authenticated
/// Shows navigation to Albums, Settings, and rotation controls
/// Requirements: 6.1, 6.2, 8.1, 8.3
struct MainView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var wallpaperManager: WallpaperManager
    @ObservedObject var photosManager: PhotosManager
    
    @State private var selectedTab: MainTab = .albums
    @State private var selectedAlbum: Album? = nil
    @State private var isStartingRotation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerView
            
            Divider()
                .foregroundColor(Theme.separator)
            
            // Main content area with navigation
            contentView
            
            Divider()
                .foregroundColor(Theme.separator)
            
            // Footer with controls
            footerView
        }
        .frame(width: 320, height: 400)
        .background(Theme.background)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("PhotoWall")
                    .font(.headline)
                    .foregroundColor(Theme.primaryText)
                
                statusText
            }
            
            Spacer()
            
            // Current photo indicator
            if let currentPhoto = wallpaperManager.currentPhoto {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "photo.fill")
                        .font(.caption)
                        .foregroundColor(Theme.secondaryText)
                        .symbolRenderingMode(.hierarchical)
                    Text(currentPhoto.filename)
                        .font(.caption)
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: 100)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.background)
        .animation(Theme.Animation.standard, value: wallpaperManager.currentPhoto?.id)
    }
    
    @ViewBuilder
    private var statusText: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .animation(Theme.Animation.standard, value: wallpaperManager.isRotating)
                .animation(Theme.Animation.standard, value: wallpaperManager.isPaused)
            
            Text(statusLabel)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        if wallpaperManager.isRotating {
            return wallpaperManager.isPaused ? Theme.warning : Theme.success
        }
        return Theme.secondaryText
    }
    
    private var statusLabel: String {
        if wallpaperManager.isRotating {
            return wallpaperManager.isPaused ? "Paused" : "Rotating"
        }
        return "Not active"
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if let album = selectedAlbum {
            PhotosView(
                album: album,
                photosManager: photosManager,
                settingsManager: settingsManager,
                onBack: { 
                    withAnimation(Theme.Animation.standard) {
                        selectedAlbum = nil
                    }
                }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
        } else {
            VStack(spacing: 0) {
                // Tab bar
                tabBar
                
                Divider()
                    .foregroundColor(Theme.separator)
                
                // Tab content
                tabContent
            }
            .transition(.opacity)
        }
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(Theme.Animation.spring) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                            .symbolRenderingMode(.hierarchical)
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .foregroundColor(selectedTab == tab ? Theme.selection : Theme.secondaryText)
                    .background(
                        selectedTab == tab ?
                        Theme.selection.opacity(0.1) :
                        Color.clear
                    )
                    .cornerRadius(Theme.CornerRadius.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .background(Theme.background)
    }

    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .albums:
            AlbumsView(
                photosManager: photosManager,
                settingsManager: settingsManager,
                onAlbumSelected: { album in
                    withAnimation(Theme.Animation.standard) {
                        selectedAlbum = album
                    }
                }
            )
            .transition(.opacity)
        case .settings:
            SettingsView(
                authManager: authManager,
                settingsManager: settingsManager
            )
            .transition(.opacity)
        }
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Selected photos count
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "photo.stack.fill")
                        .font(.caption)
                        .foregroundColor(Theme.secondaryText)
                        .symbolRenderingMode(.hierarchical)
                    Text("\(settingsManager.selectedPhotoCount) photos")
                        .font(.caption)
                        .foregroundColor(Theme.secondaryText)
                }
                
                if wallpaperManager.isRotating {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.tertiaryText)
                            .symbolRenderingMode(.hierarchical)
                        Text(formatInterval(settingsManager.rotationInterval))
                            .font(.caption2)
                            .foregroundColor(Theme.tertiaryText)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(Theme.Animation.standard, value: wallpaperManager.isRotating)
            
            Spacer()
            
            // Rotation control button
            rotationControlButton
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.background)
    }
    
    @ViewBuilder
    private var rotationControlButton: some View {
        if wallpaperManager.isRotating {
            HStack(spacing: Theme.Spacing.sm) {
                // Pause/Resume button
                Button(action: togglePause) {
                    Image(systemName: wallpaperManager.isPaused ? "play.fill" : "pause.fill")
                        .frame(width: 24, height: 24)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.bordered)
                .help(wallpaperManager.isPaused ? "Resume rotation" : "Pause rotation")
                
                // Stop button
                Button(action: stopRotation) {
                    Image(systemName: "stop.fill")
                        .frame(width: 24, height: 24)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.bordered)
                .help("Stop rotation")
            }
            .transition(.scale.combined(with: .opacity))
        } else if isStartingRotation {
            HStack(spacing: Theme.Spacing.xs) {
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(CircularProgressViewStyle())
                Text("Loading...")
                    .font(.caption)
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            Button(action: startRotation) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "play.fill")
                        .symbolRenderingMode(.hierarchical)
                    Text("Start")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(settingsManager.selectedPhotoCount == 0)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - Actions
    
    private func togglePause() {
        if wallpaperManager.isPaused {
            wallpaperManager.resumeRotation()
        } else {
            wallpaperManager.pauseRotation()
        }
    }
    
    private func stopRotation() {
        wallpaperManager.stopRotation()
    }
    
    private func startRotation() {
        // Fetch photos for selected IDs and start rotation
        isStartingRotation = true
        Task {
            await fetchAndStartRotation()
            await MainActor.run {
                isStartingRotation = false
            }
        }
    }
    
    private func fetchAndStartRotation() async {
        // Get selected photo IDs from settings
        let selectedPhotoIds = Set(settingsManager.selectedPhotoIds)
        
        guard !selectedPhotoIds.isEmpty else { return }
        
        // Fetch photos from all selected albums to get the Photo objects
        var allPhotos: [Photo] = []
        var seenPhotoIds = Set<String>()
        
        do {
            // Fetch albums first
            let albums = try await photosManager.fetchAlbums()
            
            // For each selected album, fetch its photos
            for albumId in settingsManager.selectedAlbumIds {
                if let album = albums.first(where: { $0.id == albumId }) {
                    let photos = try await photosManager.fetchPhotos(albumId: album.id)
                    // Filter to only include selected photos, avoiding duplicates
                    for photo in photos {
                        if selectedPhotoIds.contains(photo.id) && !seenPhotoIds.contains(photo.id) {
                            allPhotos.append(photo)
                            seenPhotoIds.insert(photo.id)
                        }
                    }
                }
            }
            
            // If we have photos, start rotation
            if !allPhotos.isEmpty {
                await MainActor.run {
                    wallpaperManager.startRotation(
                        photos: allPhotos,
                        interval: settingsManager.rotationInterval
                    )
                }
            }
        } catch {
            print("Failed to fetch photos for rotation: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func formatInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "Every \(minutes) min"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return "Every \(hours) hr"
        } else {
            let days = minutes / 1440
            return "Every \(days) day"
        }
    }
}
