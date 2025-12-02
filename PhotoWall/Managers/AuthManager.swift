import Foundation
import AuthenticationServices
import Combine
import CommonCrypto
import AppKit

// MARK: - AuthError

enum AuthError: Error, LocalizedError {
    case configurationMissing
    case authenticationFailed(String)
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case invalidResponse
    case networkError(Error)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "OAuth configuration is missing. Please configure client ID and redirect URI."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .invalidResponse:
            return "Invalid response from authentication server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .cancelled:
            return "Authentication was cancelled"
        }
    }
}

// MARK: - AuthManagerProtocol

@MainActor
protocol AuthManagerProtocol: ObservableObject {
    var isAuthenticated: Bool { get }
    var authState: AuthState { get }
    var accessToken: String? { get }
    
    func signIn() async throws
    func signOut() async throws
    func refreshTokenIfNeeded() async throws -> String
}

// MARK: - OAuthConfiguration

struct OAuthConfiguration {
    let clientId: String
    let clientSecret: String?
    let redirectUri: String
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let revokeEndpoint: String
    let scopes: [String]
    
    static var googlePhotos: OAuthConfiguration {
        OAuthConfiguration(
            clientId: ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? "",
            clientSecret: ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"],
            redirectUri: "com.photowall.app:/oauth2callback",
            authorizationEndpoint: "https://accounts.google.com/o/oauth2/v2/auth",
            tokenEndpoint: "https://oauth2.googleapis.com/token",
            revokeEndpoint: "https://oauth2.googleapis.com/revoke",
            scopes: [
                "https://www.googleapis.com/auth/photoslibrary.readonly",
                "openid",
                "email",
                "profile"
            ]
        )
    }
}

// MARK: - TokenResponse

private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?
    let idToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
        case idToken = "id_token"
    }
}

// MARK: - UserInfoResponse

private struct UserInfoResponse: Codable {
    let sub: String
    let email: String?
    let name: String?
    let picture: String?
}

// MARK: - AuthManager

@MainActor
final class AuthManager: NSObject, AuthManagerProtocol, ASWebAuthenticationPresentationContextProviding {
    
    // MARK: - Published Properties
    
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var authState: AuthState = .unknown
    @Published private(set) var accessToken: String?
    
    // MARK: - Private Properties
    
    private let keychainService: KeychainServiceProtocol
    private let configuration: OAuthConfiguration
    private var authSession: ASWebAuthenticationSession?
    
    // MARK: - Initialization
    
    init(
        keychainService: KeychainServiceProtocol = KeychainService(),
        configuration: OAuthConfiguration = .googlePhotos
    ) {
        self.keychainService = keychainService
        self.configuration = configuration
        super.init()
        
        Task {
            await checkExistingAuth()
        }
    }
    
    // MARK: - Check Existing Auth
    
    private func checkExistingAuth() async {
        do {
            if let credentials = try keychainService.load() {
                if credentials.isExpired {
                    // Try to refresh the token
                    _ = try await refreshTokenIfNeeded()
                } else {
                    accessToken = credentials.accessToken
                    isAuthenticated = true
                    authState = .signedIn(user: UserInfo(email: "user@gmail.com", name: nil, pictureUrl: nil))
                }
            } else {
                authState = .signedOut
            }
        } catch {
            authState = .signedOut
        }
    }
    
    // MARK: - Sign In
    
    func signIn() async throws {
        guard !configuration.clientId.isEmpty else {
            throw AuthError.configurationMissing
        }
        
        let authorizationCode = try await performOAuthFlow()
        let credentials = try await exchangeCodeForTokens(code: authorizationCode)
        
        try keychainService.save(credentials: credentials)
        
        accessToken = credentials.accessToken
        isAuthenticated = true
        authState = .signedIn(user: UserInfo(email: "user@gmail.com", name: nil, pictureUrl: nil))
    }
    
    // MARK: - OAuth Flow
    
    private func performOAuthFlow() async throws -> String {
        let state = UUID().uuidString
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        var components = URLComponents(string: configuration.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        guard let authURL = components.url else {
            throw AuthError.authenticationFailed("Failed to construct authorization URL")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.photowall.app"
            ) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code == .canceledLogin {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthError.authenticationFailed(error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.invalidResponse)
                    return
                }
                
                // Verify state matches
                let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
                guard returnedState == state else {
                    continuation.resume(throwing: AuthError.authenticationFailed("State mismatch"))
                    return
                }
                
                // Store code verifier for token exchange
                UserDefaults.standard.set(codeVerifier, forKey: "oauth_code_verifier")
                
                continuation.resume(returning: code)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            self.authSession = session
            session.start()
        }
    }
    
    // MARK: - Token Exchange
    
    private func exchangeCodeForTokens(code: String) async throws -> OAuthCredentials {
        let codeVerifier = UserDefaults.standard.string(forKey: "oauth_code_verifier") ?? ""
        
        var request = URLRequest(url: URL(string: configuration.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectUri)
        ]
        
        if let clientSecret = configuration.clientSecret {
            bodyComponents.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            // Debug: Print the scope that was actually granted
            print("Token exchange successful. Granted scope: \(tokenResponse.scope ?? "none")")
            
            let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            
            return OAuthCredentials(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? "",
                expiresAt: expiresAt
            )
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }
    
    // MARK: - Token Refresh
    
    func refreshTokenIfNeeded() async throws -> String {
        guard let credentials = try keychainService.load() else {
            throw AuthError.tokenRefreshFailed("No stored credentials")
        }
        
        // If token is still valid, return it
        if !credentials.isExpired {
            return credentials.accessToken
        }
        
        // Refresh the token
        var request = URLRequest(url: URL(string: configuration.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "refresh_token", value: credentials.refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        
        if let clientSecret = configuration.clientSecret {
            bodyComponents.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Token refresh failed, clear credentials and require re-auth
                try? keychainService.delete()
                isAuthenticated = false
                authState = .signedOut
                accessToken = nil
                
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.tokenRefreshFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            
            // Keep the existing refresh token if a new one wasn't provided
            let newCredentials = OAuthCredentials(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? credentials.refreshToken,
                expiresAt: expiresAt
            )
            
            try keychainService.save(credentials: newCredentials)
            
            accessToken = newCredentials.accessToken
            
            return newCredentials.accessToken
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        // Revoke the token if we have one
        if let credentials = try? keychainService.load() {
            await revokeToken(credentials.accessToken)
        }
        
        // Clear stored credentials
        try keychainService.delete()
        
        // Update state
        accessToken = nil
        isAuthenticated = false
        authState = .signedOut
    }
    
    private func revokeToken(_ token: String) async {
        var request = URLRequest(url: URL(string: configuration.revokeEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "token", value: token)
        ]
        
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        // Fire and forget - we don't care if revocation fails
        _ = try? await URLSession.shared.data(for: request)
    }
    
    // MARK: - PKCE Helpers
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return a window from the main thread
        return MainActor.assumeIsolated {
            NSApplication.shared.keyWindow ?? NSWindow()
        }
    }
}
