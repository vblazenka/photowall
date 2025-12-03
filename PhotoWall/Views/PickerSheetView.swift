import SwiftUI
import AuthenticationServices

// MARK: - PickerSheetView

struct PickerSheetView: View {

    // MARK: - Dependencies

    let photosManager: PhotosManager
    let onComplete: ([Photo]) -> Void
    let onCancel: () -> Void

    // MARK: - State

    @State private var state: PickerState = .creatingSession
    @State private var pickerSession: PickerSessionResponse?
    @State private var errorMessage: String?
    @State private var authSession: ASWebAuthenticationSession?

    // MARK: - PickerState

    private enum PickerState {
        case creatingSession
        case showingPicker
        case fetchingPhotos
        case error
        case completed
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Select Photos")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: handleCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding()

            // Content
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Error message if present
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .frame(width: 800, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await createSession()
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch state {
        case .creatingSession:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Creating photo picker session...")
                    .foregroundColor(.secondary)
            }

        case .showingPicker:
            if let session = pickerSession {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Opening Google Photos Picker in browser...")
                        .foregroundColor(.secondary)
                    Text("The picker will open in your default browser.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    // Open picker in browser using ASWebAuthenticationSession
                    Task {
                        await openPickerInBrowser(session: session)
                    }
                }
            } else {
                Text("Failed to load picker")
                    .foregroundColor(.red)
            }

        case .fetchingPhotos:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Fetching selected photos...")
                    .foregroundColor(.secondary)
            }

        case .error:
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text(errorMessage ?? "An error occurred")
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task {
                        await createSession()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

        case .completed:
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Photos selected successfully!")
            }
        }
    }

    // MARK: - Actions

    private func createSession() async {
        state = .creatingSession
        errorMessage = nil

        do {
            let session = try await photosManager.createPickerSession(maxItemCount: nil)
            pickerSession = session
            state = .showingPicker
        } catch {
            errorMessage = "Failed to create picker session: \(error.localizedDescription)"
            state = .error
        }
    }

    private func handlePickerComplete(_ success: Bool) {
        guard success else {
            handleCancel()
            return
        }

        Task {
            await fetchSelectedPhotos()
        }
    }

    private func openPickerInBrowser(session: PickerSessionResponse) async {
        guard let pickerUri = session.pickerUri,
              let url = URL(string: pickerUri) else {
            await MainActor.run {
                errorMessage = "Invalid picker URL"
                state = .error
            }
            return
        }

        print("=== Opening Picker in Browser ===")
        print("URL: \(url.absoluteString)")
        print("Session ID: \(session.id)")

        await MainActor.run {
            let callbackScheme = "com.photowall.app"

            self.authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [self] callbackURL, error in
                Task {
                    await self.handleBrowserPickerComplete(callbackURL: callbackURL, error: error, sessionId: session.id)
                }
            }

            authSession?.presentationContextProvider = PickerPresentationContext.shared
            authSession?.prefersEphemeralWebBrowserSession = false // Share cookies with Safari

            if authSession?.start() == false {
                errorMessage = "Failed to open picker in browser"
                state = .error
            }
        }
    }

    private func handleBrowserPickerComplete(callbackURL: URL?, error: Error?, sessionId: String) async {
        print("=== Browser Picker Completed ===")

        if let error = error {
            print("Error: \(error)")

            // ASWebAuthenticationSession reports "cancelled" when browser window closes
            // This is expected behavior - Google tells users to close the window when done
            // So we poll the session to check if photos were actually selected
            let nsError = error as NSError
            if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
               nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                print("Browser window closed - polling session to check for selections...")
                await pollSessionAndFetchPhotos(sessionId: sessionId)
                return
            }

            // Other errors - treat as actual failure
            await MainActor.run {
                errorMessage = "Picker error: \(error.localizedDescription)"
                state = .error
            }
            return
        }

        if let callbackURL = callbackURL {
            print("Callback URL: \(callbackURL)")
        }

        // If we got a callback (unlikely), poll the session
        await pollSessionAndFetchPhotos(sessionId: sessionId)
    }

    private func pollSessionAndFetchPhotos(sessionId: String) async {
        print("=== Polling Session ===")
        print("Session ID: \(sessionId)")

        await MainActor.run {
            state = .fetchingPhotos
            errorMessage = nil
        }

        // Poll the session to check if mediaItemsSet is true
        let maxAttempts = 60 // Poll for up to 5 minutes (60 * 5 seconds)
        let pollInterval: UInt64 = 5_000_000_000 // 5 seconds in nanoseconds

        for attempt in 1...maxAttempts {
            do {
                print("Poll attempt \(attempt)/\(maxAttempts)")
                let session = try await photosManager.getPickerSession(sessionId: sessionId)

                print("Session status - mediaItemsSet: \(session.mediaItemsSet ?? false)")

                if session.mediaItemsSet == true {
                    print("Photos selected! Fetching media items...")
                    await fetchSelectedPhotos()
                    return
                }

                // Wait before next poll
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: pollInterval)
                }
            } catch {
                print("Error polling session: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to check session status: \(error.localizedDescription)"
                    state = .error
                }
                return
            }
        }

        // Timeout - no photos selected
        print("Polling timeout - no photos selected")
        await MainActor.run {
            errorMessage = "No photos were selected or selection timed out"
            state = .error
        }
    }

    private func fetchSelectedPhotos() async {
        guard let session = pickerSession else {
            errorMessage = "No session available"
            onCancel()
            return
        }

        await MainActor.run {
            state = .fetchingPhotos
            errorMessage = nil
        }

        do {
            print("=== PickerSheetView: Fetching photos for session \(session.id) ===")
            let photos = try await photosManager.fetchPhotosFromPicker(sessionId: session.id)
            print("=== PickerSheetView: Received \(photos.count) photos ===")

            if photos.isEmpty {
                await MainActor.run {
                    errorMessage = "No photos were selected"
                    state = .error
                }
            } else {
                await MainActor.run {
                    state = .completed
                }

                // Small delay to show success state
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                await MainActor.run {
                    onComplete(photos)
                }
            }
        } catch {
            print("=== PickerSheetView: Error fetching photos ===")
            print("Error: \(error)")
            await MainActor.run {
                errorMessage = "Failed to fetch photos: \(error.localizedDescription)"
                state = .error
            }
        }
    }

    private func handleCancel() {
        onCancel()
    }
}

// MARK: - PickerPresentationContext

/// Helper class to provide presentation context for ASWebAuthenticationSession
class PickerPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PickerPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSApplication.shared.windows.first!
    }
}

// MARK: - Preview

#Preview {
    let authManager = AuthManager()
    let pickerService = PhotosPickerService(authManager: authManager)
    let photosManager = PhotosManager(authManager: authManager, pickerService: pickerService)

    return PickerSheetView(
        photosManager: photosManager,
        onComplete: { photos in
            print("Selected \(photos.count) photos")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
