import SwiftUI

/// View for selecting photos via Google Photos Picker
struct AlbumsView: View {
    @ObservedObject var photosManager: PhotosManager
    @ObservedObject var settingsManager: SettingsManager

    @State private var showingPicker = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Header
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.selection)
                    .symbolRenderingMode(.hierarchical)

                Text("Photo Selection")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primaryText)
            }
            .padding(.top, Theme.Spacing.xl)

            // Selection Status
            if let cache = settingsManager.pickerCache {
                selectedPhotosView(cache: cache)
            } else {
                noPhotosSelectedView
            }

            Spacer()

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(Theme.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .sheet(isPresented: $showingPicker) {
            PickerSheetView(
                photosManager: photosManager,
                onComplete: handlePhotosSelected,
                onCancel: {
                    showingPicker = false
                }
            )
        }
    }

    // MARK: - No Photos Selected View

    private var noPhotosSelectedView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("No photos selected")
                .font(.subheadline)
                .foregroundColor(Theme.secondaryText)

            Text("Select photos from your Google Photos library to use for wallpaper rotation.")
                .font(.caption)
                .foregroundColor(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Button(action: {
                errorMessage = nil
                showingPicker = true
            }) {
                Label("Select Photos from Google Photos", systemImage: "photo.on.rectangle.angled")
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - Selected Photos View

    private func selectedPhotosView(cache: PickerCache) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            // Photo count
            VStack(spacing: Theme.Spacing.xs) {
                Text("\(cache.photos.count)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.selection)

                Text(cache.photos.count == 1 ? "photo selected" : "photos selected")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryText)
            }

            // Selection date
            Text("Selected on \(formatDate(cache.selectionDate))")
                .font(.caption)
                .foregroundColor(Theme.tertiaryText)

            // Staleness warning
            if cache.isStale {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Selection is over 7 days old - consider re-selecting")
                }
                .font(.caption)
                .foregroundColor(Theme.warning)
                .padding(Theme.Spacing.sm)
                .background(Theme.warning.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.small)
            }

            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                Button(action: {
                    errorMessage = nil
                    showingPicker = true
                }) {
                    Label("Select Different Photos", systemImage: "arrow.triangle.2.circlepath")
                        .padding(.horizontal, Theme.Spacing.sm)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    settingsManager.clearPickerCache()
                }) {
                    Label("Clear Selection", systemImage: "trash")
                        .padding(.horizontal, Theme.Spacing.sm)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - Actions

    private func handlePhotosSelected(_ photos: [Photo]) {
        showingPicker = false

        // Cache the selected photos
        settingsManager.cacheSelectedPhotos(photos)

        // Show success feedback
        errorMessage = nil
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    AlbumsView(
        photosManager: PhotosManager(
            authManager: AuthManager(),
            pickerService: PhotosPickerService(authManager: AuthManager())
        ),
        settingsManager: SettingsManager()
    )
}
