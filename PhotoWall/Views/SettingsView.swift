import SwiftUI

/// Rotation interval options
enum RotationInterval: TimeInterval, CaseIterable, Identifiable {
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case oneDay = 86400
    
    var id: TimeInterval { rawValue }
    
    var displayName: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        }
    }
    
    static func from(interval: TimeInterval) -> RotationInterval {
        // Find the closest matching interval
        return allCases.min(by: { abs($0.rawValue - interval) < abs($1.rawValue - interval) }) ?? .oneHour
    }
}

/// Settings view for configuring rotation interval and managing account
/// Requirements: 3.1, 3.2, 6.1, 6.2, 7.1
struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var settingsManager: SettingsManager
    
    @State private var selectedInterval: RotationInterval = .oneHour
    @State private var cacheSize: String = "Calculating..."
    @State private var isSigningOut = false
    @State private var isClearingCache = false
    @State private var showSignOutConfirmation = false
    
    private let imageCacheService = ImageCacheService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                // Rotation Interval Section
                rotationIntervalSection
                    .fadeIn()
                
                Divider()
                    .foregroundColor(Theme.separator)
                
                // Cache Section
                cacheSection
                    .fadeIn()
                
                Divider()
                    .foregroundColor(Theme.separator)
                
                // Account Section
                accountSection
                    .fadeIn()
            }
            .padding(Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            selectedInterval = RotationInterval.from(interval: settingsManager.rotationInterval)
            updateCacheSize()
        }
    }
    
    // MARK: - Rotation Interval Section
    
    private var rotationIntervalSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Rotation Interval", systemImage: "clock.fill")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.primaryText)
                .symbolRenderingMode(.hierarchical)
            
            Picker("Interval", selection: $selectedInterval) {
                ForEach(RotationInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: selectedInterval) { newValue in
                withAnimation(Theme.Animation.standard) {
                    settingsManager.rotationInterval = newValue.rawValue
                }
            }
            
            Text("How often the wallpaper will change")
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
        }
    }
    
    // MARK: - Cache Section
    
    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Image Cache", systemImage: "internaldrive.fill")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.primaryText)
                .symbolRenderingMode(.hierarchical)
            
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Cache Size")
                        .font(.caption)
                        .foregroundColor(Theme.primaryText)
                    Text(cacheSize)
                        .font(.caption)
                        .foregroundColor(Theme.secondaryText)
                }
                
                Spacer()
                
                Button(action: clearCache) {
                    if isClearingCache {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 60)
                    } else {
                        Label("Clear", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isClearingCache)
            }
            
            Text("Cached images are stored locally for faster loading")
                .font(.caption)
                .foregroundColor(Theme.tertiaryText)
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Account", systemImage: "person.circle.fill")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.primaryText)
                .symbolRenderingMode(.hierarchical)
            
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Google Account")
                        .font(.caption)
                        .foregroundColor(Theme.primaryText)
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(Theme.success)
                            .frame(width: 6, height: 6)
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(Theme.success)
                    }
                }
                
                Spacer()
                
                Button(action: { showSignOutConfirmation = true }) {
                    if isSigningOut {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 70)
                    } else {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isSigningOut)
            }
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? Wallpaper rotation will stop.")
        }
    }

    
    // MARK: - Actions
    
    private func updateCacheSize() {
        let bytes = imageCacheService.cacheSize()
        cacheSize = formatBytes(bytes)
    }
    
    private func clearCache() {
        isClearingCache = true
        
        Task {
            do {
                try imageCacheService.clearCache()
                await MainActor.run {
                    updateCacheSize()
                    isClearingCache = false
                }
            } catch {
                await MainActor.run {
                    isClearingCache = false
                }
            }
        }
    }
    
    private func signOut() {
        isSigningOut = true
        
        Task {
            do {
                try await authManager.signOut()
            } catch {
                // Error handling - sign out failed
                print("Sign out error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isSigningOut = false
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
