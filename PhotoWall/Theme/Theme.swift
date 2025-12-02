import SwiftUI

/// Centralized theme configuration for PhotoWall
/// Supports automatic light/dark mode switching based on system appearance
/// Requirements: 6.1, 6.2
enum Theme {
    
    // MARK: - Colors
    
    /// Primary background color - adapts to light/dark mode
    static var background: Color {
        Color(NSColor.windowBackgroundColor)
    }
    
    /// Secondary background for cards and cells
    static var secondaryBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    /// Tertiary background for nested elements
    static var tertiaryBackground: Color {
        Color(NSColor.underPageBackgroundColor)
    }
    
    /// Primary text color
    static var primaryText: Color {
        Color(NSColor.labelColor)
    }
    
    /// Secondary text color for subtitles and captions
    static var secondaryText: Color {
        Color(NSColor.secondaryLabelColor)
    }
    
    /// Tertiary text color for hints and placeholders
    static var tertiaryText: Color {
        Color(NSColor.tertiaryLabelColor)
    }
    
    /// Separator/divider color
    static var separator: Color {
        Color(NSColor.separatorColor)
    }
    
    /// Selection highlight color
    static var selection: Color {
        Color.accentColor
    }
    
    /// Success indicator color
    static var success: Color {
        Color.green
    }
    
    /// Warning indicator color
    static var warning: Color {
        Color.orange
    }
    
    /// Error indicator color
    static var error: Color {
        Color.red
    }
    
    /// Placeholder background for loading states
    static var placeholder: Color {
        Color(NSColor.placeholderTextColor).opacity(0.1)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
    }
    
    // MARK: - Animation
    
    enum Animation {
        /// Standard animation for UI transitions
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.2)
        
        /// Spring animation for interactive elements
        static let spring: SwiftUI.Animation = .spring(response: 0.3, dampingFraction: 0.7)
        
        /// Slow animation for loading states
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.5)
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let small = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - View Extensions

extension View {
    /// Apply theme shadow
    func themeShadow(_ style: Theme.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
    
    /// Shimmer loading effect for placeholder content
    func shimmer(isActive: Bool = true) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
    
    /// Fade in animation when view appears
    func fadeIn() -> some View {
        self.modifier(FadeInModifier())
    }
}

// MARK: - Shimmer Effect Modifier

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                Color.white.opacity(0.3),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    }
                )
                .mask(content)
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Fade In Modifier

struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(Theme.Animation.standard) {
                    opacity = 1
                }
            }
    }
}

// MARK: - Loading Placeholder View

struct LoadingPlaceholder: View {
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = Theme.CornerRadius.medium) {
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.placeholder)
            .shimmer()
    }
}

// MARK: - Animated Progress View

struct AnimatedProgressView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ProgressView()
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.6)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}
