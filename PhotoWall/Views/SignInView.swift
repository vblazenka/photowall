import SwiftUI

/// Sign-in view displayed when user is not authenticated
/// Requirements: 1.1, 1.2, 6.1, 6.2
struct SignInView: View {
    @ObservedObject var authManager: AuthManager
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()
            
            // App icon and title
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundColor(Theme.selection)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(hasAppeared ? 1.0 : 0.8)
                    .opacity(hasAppeared ? 1.0 : 0)
                
                Text("PhotoWall")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primaryText)
                    .opacity(hasAppeared ? 1.0 : 0)
                
                Text("Automatically rotate your Google Photos as wallpapers")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .opacity(hasAppeared ? 1.0 : 0)
            }
            .animation(Theme.Animation.spring.delay(0.1), value: hasAppeared)
            
            Spacer()
            
            // Sign-in button
            VStack(spacing: Theme.Spacing.lg) {
                Button(action: signIn) {
                    HStack(spacing: Theme.Spacing.sm) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 18))
                                .symbolRenderingMode(.hierarchical)
                        }
                        Text(isLoading ? "Signing in..." : "Sign in with Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                .padding(.horizontal, 40)
                .scaleEffect(hasAppeared ? 1.0 : 0.9)
                .opacity(hasAppeared ? 1.0 : 0)
                .animation(Theme.Animation.spring.delay(0.2), value: hasAppeared)
                
                Text("Access your photos securely with OAuth 2.0")
                    .font(.caption)
                    .foregroundColor(Theme.tertiaryText)
                    .opacity(hasAppeared ? 1.0 : 0)
                    .animation(Theme.Animation.standard.delay(0.3), value: hasAppeared)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            withAnimation {
                hasAppeared = true
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signIn()
            } catch AuthError.cancelled {
                // User cancelled - no error to show
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    SignInView(authManager: AuthManager())
        .frame(width: 320, height: 480)
}
