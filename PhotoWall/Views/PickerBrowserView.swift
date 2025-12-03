import SwiftUI
import AuthenticationServices

// MARK: - PickerBrowserView

/// Opens Google Photos Picker in ASWebAuthenticationSession
/// This shares authentication state with Safari, avoiding re-sign-in
struct PickerBrowserView: NSViewRepresentable {

    let pickerUri: String
    let sessionId: String
    let onComplete: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        // Start the authentication session on the next run loop
        DispatchQueue.main.async {
            context.coordinator.startPickerSession(pickerUri: pickerUri, sessionId: sessionId)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
        let parent: PickerBrowserView
        private var authSession: ASWebAuthenticationSession?
        private var hasCompleted = false

        init(parent: PickerBrowserView) {
            self.parent = parent
        }

        func startPickerSession(pickerUri: String, sessionId: String) {
            guard let url = URL(string: pickerUri) else {
                print("=== PickerBrowserView: Invalid picker URI ===")
                parent.onComplete(false)
                return
            }

            print("=== PickerBrowserView: Starting picker session ===")
            print("Picker URI: \(pickerUri)")
            print("Session ID: \(sessionId)")

            // Create callback URL scheme
            // The picker might redirect to a completion URL, but we'll also poll the session
            let callbackScheme = "com.photowall.app"

            authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }

                print("=== PickerBrowserView: Session completed ===")
                if let error = error {
                    print("Error: \(error)")

                    // Check if user cancelled
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        print("User cancelled picker")
                        if !self.hasCompleted {
                            self.hasCompleted = true
                            self.parent.onComplete(false)
                        }
                        return
                    }
                }

                if let callbackURL = callbackURL {
                    print("Callback URL: \(callbackURL)")
                }

                // Session completed successfully (user closed picker or completed selection)
                if !self.hasCompleted {
                    self.hasCompleted = true
                    self.parent.onComplete(true)
                }
            }

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false // Share cookies with Safari

            if authSession?.start() == true {
                print("=== PickerBrowserView: Session started successfully ===")
            } else {
                print("=== PickerBrowserView: Failed to start session ===")
                parent.onComplete(false)
            }
        }

        // MARK: - ASWebAuthenticationPresentationContextProviding

        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            // Return the main window
            return NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSApplication.shared.windows.first!
        }
    }
}
