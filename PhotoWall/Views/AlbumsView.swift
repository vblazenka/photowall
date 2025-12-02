import SwiftUI

/// View displaying user's Google Photos albums in a grid layout
/// Requirements: 2.1, 6.2, 6.3, 6.4
struct AlbumsView: View {
    @ObservedObject var photosManager: PhotosManager
    @ObservedObject var settingsManager: SettingsManager
    
    let onAlbumSelected: (Album) -> Void
    
    @State private var albums: [Album] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var hasAppeared = false
    
    var body: some View {
        Group {
            if isLoading && albums.isEmpty {
                loadingView
                    .transition(.opacity)
            } else if let error = errorMessage, albums.isEmpty {
                errorView(error)
                    .transition(.opacity)
            } else if albums.isEmpty {
                emptyView
                    .transition(.opacity)
            } else {
                albumsGrid
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .animation(Theme.Animation.standard, value: isLoading)
        .animation(Theme.Animation.standard, value: albums.isEmpty)
        .task {
            await loadAlbums()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            AnimatedProgressView()
            Text("Loading albums...")
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.warning)
                .symbolRenderingMode(.hierarchical)
            
            Text("Failed to load albums")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.primaryText)
            
            Text(message)
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task { await loadAlbums() }
            }) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.secondaryText)
                .symbolRenderingMode(.hierarchical)
            
            Text("No albums found")
                .font(.subheadline)
                .foregroundColor(Theme.secondaryText)
            
            Button(action: {
                Task { await loadAlbums() }
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Albums Grid
    
    private var albumsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.md),
                    GridItem(.flexible(), spacing: Theme.Spacing.md)
                ],
                spacing: Theme.Spacing.md
            ) {
                ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                    AlbumCell(
                        album: album,
                        isSelected: settingsManager.isAlbumSelected(album),
                        onTap: { onAlbumSelected(album) }
                    )
                    .fadeIn()
                    .animation(
                        Theme.Animation.spring.delay(Double(index) * 0.03),
                        value: hasAppeared
                    )
                }
            }
            .padding(Theme.Spacing.md)
        }
        .refreshable {
            await loadAlbums()
        }
        .onAppear {
            withAnimation {
                hasAppeared = true
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadAlbums() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedAlbums = try await photosManager.fetchAlbums()
            await MainActor.run {
                albums = fetchedAlbums
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Album Cell

struct AlbumCell: View {
    let album: Album
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var coverImage: NSImage? = nil
    @State private var isLoadingImage = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Cover image
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .fill(Theme.placeholder)
                    
                    if let image = coverImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100)
                            .clipped()
                            .cornerRadius(Theme.CornerRadius.medium)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else if isLoadingImage {
                        LoadingPlaceholder(cornerRadius: Theme.CornerRadius.medium)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.tertiaryText)
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    // Selection indicator
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.selection)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .padding(2)
                                    )
                                    .padding(Theme.Spacing.sm)
                            }
                            Spacer()
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Hover overlay
                    if isHovered && !isSelected {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(Color.white.opacity(0.1))
                    }
                }
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(isSelected ? Theme.selection : Color.clear, lineWidth: 2)
                )
                .animation(Theme.Animation.spring, value: isSelected)
                .animation(Theme.Animation.standard, value: isHovered)
                
                // Album info
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(album.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let count = album.mediaItemsCount {
                        Text("\(count) photos")
                            .font(.caption2)
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(Theme.Animation.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            await loadCoverImage()
        }
    }
    
    private func loadCoverImage() async {
        guard let urlString = album.coverPhotoBaseUrl,
              let url = URL(string: "\(urlString)=w200-h200-c") else {
            return
        }
        
        isLoadingImage = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                await MainActor.run {
                    withAnimation(Theme.Animation.standard) {
                        coverImage = image
                        isLoadingImage = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                isLoadingImage = false
            }
        }
    }
}
