import SwiftUI
import AppKit
import Combine

@main
struct PhotoWallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var displayChangeObserver: Any?
    
    // Shared managers for app lifecycle management
    private var wallpaperManager: WallpaperManager?
    private var settingsManager: SettingsManager?
    private var photosManager: PhotosManager?
    private var authManager: AuthManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupManagers()
        setupMenuBar()
        setupEventMonitor()
        setupDisplayChangeMonitoring()
    }
    
    @MainActor
    private func setupManagers() {
        authManager = AuthManager()
        settingsManager = SettingsManager()
        photosManager = PhotosManager(authManager: authManager!)
        wallpaperManager = WallpaperManager(photosManager: photosManager!)
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "PhotoWall")
            button.action = #selector(handleMenuBarClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 480)
        popover?.behavior = .transient
        
        // Create ContentView with shared managers
        if let auth = authManager, let settings = settingsManager, let photos = photosManager, let wallpaper = wallpaperManager {
            let contentView = ContentView(
                authManager: auth,
                settingsManager: settings,
                photosManager: photos,
                wallpaperManager: wallpaper
            )
            popover?.contentViewController = NSHostingController(rootView: contentView)
        }
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                self?.closePopover()
            }
        }
    }
    
    /// Sets up monitoring for display connection changes
    /// Requirements: 5.2
    private func setupDisplayChangeMonitoring() {
        displayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDisplayChange()
        }
    }
    
    /// Handles display connection/disconnection events
    /// Requirements: 5.2
    private func handleDisplayChange() {
        guard let wallpaperManager = wallpaperManager,
              wallpaperManager.isRotating,
              let currentPhoto = wallpaperManager.currentPhoto else {
            return
        }
        
        // Apply current wallpaper to all displays (including newly connected ones)
        Task {
            do {
                try await wallpaperManager.setWallpaper(photo: currentPhoto)
            } catch {
                print("Failed to apply wallpaper to new display: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func handleMenuBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }
    
    @objc func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    func showPopover() {
        if let button = statusItem?.button, let popover = popover {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func closePopover() {
        popover?.performClose(nil)
    }
    
    /// Shows the context menu with Quit option
    /// Requirements: 4.5
    private func showContextMenu() {
        let menu = NSMenu()
        
        // Pause/Resume option
        if let wallpaperManager = wallpaperManager, wallpaperManager.isRotating {
            if wallpaperManager.isPaused {
                menu.addItem(NSMenuItem(title: "Resume Rotation", action: #selector(resumeRotation), keyEquivalent: ""))
            } else {
                menu.addItem(NSMenuItem(title: "Pause Rotation", action: #selector(pauseRotation), keyEquivalent: ""))
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quit PhotoWall", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func pauseRotation() {
        wallpaperManager?.pauseRotation()
        settingsManager?.isPaused = true
    }
    
    @objc private func resumeRotation() {
        wallpaperManager?.resumeRotation()
        settingsManager?.isPaused = false
    }
    
    /// Quits the application gracefully
    /// Requirements: 4.5
    @objc private func quitApp() {
        // Save current state before quitting
        saveCurrentState()
        
        // Stop wallpaper rotation
        wallpaperManager?.stopRotation()
        
        // Terminate the application
        NSApplication.shared.terminate(nil)
    }
    
    /// Saves the current application state before termination
    /// Requirements: 4.5
    private func saveCurrentState() {
        guard let settingsManager = settingsManager, let wallpaperManager = wallpaperManager else {
            return
        }
        
        // Save pause state
        settingsManager.isPaused = wallpaperManager.isPaused
        
        // UserDefaults automatically synchronizes, but force sync for safety
        UserDefaults.standard.synchronize()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up event monitor
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        
        // Clean up display change observer
        if let displayChangeObserver = displayChangeObserver {
            NotificationCenter.default.removeObserver(displayChangeObserver)
        }
        
        // Save state and stop rotation
        saveCurrentState()
        wallpaperManager?.stopRotation()
    }
}
