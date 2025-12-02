import SwiftUI

/// View for displaying and selecting photos from an album
/// Requirements: 2.2, 2.3, 2.4, 6.2, 6.3, 6.4
struct PhotosView: View {
    let album: Album
    @ObservedObject var photosManager: PhotosManager
    @ObservedObject var settingsManager: SettingsManager
    let onBack: () -> Void
    
    @State private var photos: [Photo] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and album info
            headerView
            
            Divider()
                .foregroundColor(Theme.separator)
            
            // Photos content
            contentView
            
            // Selection footer
            if !photos.isEmpty {
                Divider()
                    .foregroundColor(Theme.separator)
                selectionFooter
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Theme.background)
        .animation(Theme.Animation.standard, value: photos.isEmpty)
        .task {
            await loadPhotos()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.selection)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            
            VStack(alignment: .leading, spacing: 1) {
                Text(album.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                
                Text("\(selectedCount) of \(photos.count) selected")
                    .font(.caption2)
                    .foregroundColor(Theme.secondaryText)
            }
            
            Spacer()
            
            // Select All / Deselect All button
            if !photos.isEmpty {
                Button(action: toggleSelectAll) {
                    Label(
                        allSelected ? "Deselect All" : "Select All",
                        systemImage: allSelected ? "checkmark.circle" : "checkmark.circle.fill"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .animation(Theme.Animation.standard, value: allSelected)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.background)
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading && photos.isEmpty {
            loadingView
        } else if let error = errorMessage, photos.isEmpty {
            errorView(error)
        } else if photos.isEmpty {
            emptyView
        } else {
            photosGrid
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            AnimatedProgressView()
            Text("Loading photos...")
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.warning)
                .symbolRenderingMode(.hierarchical)
            
            Text("Failed to load photos")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.primaryText)
            
            Text(message)
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task { await loadPhotos() }
            }) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "photo.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.secondaryText)
                .symbolRenderingMode(.hierarchical)
            
            Text("No photos in this album")
                .font(.subheadline)
                .foregroundColor(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
    
    // MARK: - Photos Grid
    
    private var photosGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.xs),
                    GridItem(.flexible(), spacing: Theme.Spacing.xs),
                    GridItem(.flexible(), spacing: Theme.Spacing.xs)
                ],
                spacing: Theme.Spacing.xs
            ) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    PhotoCell(
                        photo: photo,
                        isSelected: settingsManager.isPhotoSelected(photo),
                        onTap: { togglePhotoSelection(photo) }
                    )
                    .animation(
                        Theme.Animation.spring.delay(Double(index) * 0.02),
                        value: hasAppeared
                    )
                }
            }
            .padding(Theme.Spacing.xs)
        }
        .onAppear {
            withAnimation {
                hasAppeared = true
            }
        }
    }

    
    // MARK: - Selection Footer
    
    private var selectionFooter: some View {
        HStack {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.selection)
                    .font(.caption)
                Text("\(selectedCount) photos selected")
                    .font(.caption)
                    .foregroundColor(Theme.secondaryText)
            }
            .animation(Theme.Animation.spring, value: selectedCount)
            
            Spacer()
            
            Button(action: onBack) {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.background)
    }
    
    // MARK: - Computed Properties
    
    private var selectedCount: Int {
        photos.filter { settingsManager.isPhotoSelected($0) }.count
    }
    
    private var allSelected: Bool {
        !photos.isEmpty && photos.allSatisfy { settingsManager.isPhotoSelected($0) }
    }
    
    // MARK: - Actions
    
    private func togglePhotoSelection(_ photo: Photo) {
        if settingsManager.isPhotoSelected(photo) {
            settingsManager.deselectPhoto(photo)
        } else {
            settingsManager.selectPhoto(photo)
        }
    }
    
    private func toggleSelectAll() {
        if allSelected {
            // Deselect all photos in this album
            settingsManager.deselectAlbum(album, photos: photos)
        } else {
            // Select all photos in this album
            settingsManager.selectAlbum(album, photos: photos)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadPhotos() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedPhotos = try await photosManager.fetchPhotos(albumId: album.id)
            await MainActor.run {
                photos = fetchedPhotos
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

// MARK: - Photo Cell

struct PhotoCell: View {
    let photo: Photo
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: NSImage? = nil
    @State private var isLoadingImage = false
    @State private var isHovered = false
    
    private let cellSize: CGFloat = 90
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                    .fill(Theme.placeholder)
                
                // Thumbnail image
                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cellSize, height: cellSize)
                        .clipped()
                        .cornerRadius(Theme.CornerRadius.small)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if isLoadingImage {
                    LoadingPlaceholder(cornerRadius: Theme.CornerRadius.small)
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.tertiaryText)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // Selection overlay
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .stroke(Theme.selection, lineWidth: 3)
                    
                    // Dimming overlay for selected items
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(Theme.selection.opacity(0.15))
                    
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.selection)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .padding(2)
                                )
                                .padding(Theme.Spacing.xs)
                        }
                        Spacer()
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Hover overlay
                if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(Color.white.opacity(0.15))
                }
            }
            .frame(width: cellSize, height: cellSize)
            .animation(Theme.Animation.spring, value: isSelected)
            .animation(Theme.Animation.standard, value: isHovered)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(Theme.Animation.spring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard let url = URL(string: photo.thumbnailUrl) else { return }
        
        isLoadingImage = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                await MainActor.run {
                    withAnimation(Theme.Animation.standard) {
                        thumbnailImage = image
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
