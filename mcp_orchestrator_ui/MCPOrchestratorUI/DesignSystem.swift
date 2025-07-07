import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // 🌗 Background Layers (for depth & glass look)
        static let backgroundBase = Color(hex: "#F8F8F8")
        static let backgroundBaseDark = Color(hex: "#1A1A1A")
        
        // Glass panel / modal with glassmorphism effect
        static let glassPanel = Color.white.opacity(0.6)
        static let glassPanelDark = Color(hex: "#1E1E1E").opacity(0.5)
        
        // Card background
        static let surfaceElevated = Color.white.opacity(0.85)
        static let surfaceElevatedDark = Color(hex: "#181818").opacity(0.85)
        
        // Sidebar
        static let surface = Color(hex: "#F5F5F5").opacity(0.9)
        static let surfaceDark = Color(hex: "#282828").opacity(0.9)
        
        // 🔤 Typography (Clean, Calm, Readable)
        static let textPrimary = Color(hex: "#1C1C1E")
        static let textPrimaryDark = Color.white
        
        static let textSecondary = Color(hex: "#6E6E73")
        static let textSecondaryDark = Color(hex: "#B0B0B0")
        
        static let textTertiary = Color(hex: "#A1A1A1")
        static let textTertiaryDark = Color(hex: "#666666")
        
        // Muted text (for disabled/placeholder states)
        static let textMuted = Color(hex: "#C7C7CC")
        static let textMutedDark = Color(hex: "#48484A")
        
        // Interactive text (e.g., link)
        static let accentPrimary = Color(hex: "#0A84FF")
        static let accentPrimaryDark = Color(hex: "#64D2FF")
        
        // 🧩 MCP Status Color Chips (Minimal & Functional)
        static let statusSuccess = Color(hex: "#30D158") // Active / Connected
        static let statusSyncing = Color(hex: "#64D2FF") // Syncing
        static let statusWarning = Color(hex: "#FFD60A") // Warning
        static let statusError = Color(hex: "#FF453A") // Error / Disconnected
        static let statusIdle = Color(hex: "#D1D1D6") // Idle / Sleep
        
        // 🔘 UI Elements (Buttons, Controls)
        static let buttonPrimary = Color(hex: "#0A84FF")
        static let buttonPrimaryText = Color.white
        
        static let buttonSecondary = Color(hex: "#F0F0F0")
        static let buttonSecondaryDark = Color(hex: "#2C2C2E")
        static let buttonSecondaryText = Color(hex: "#333333")
        static let buttonSecondaryTextDark = Color(hex: "#EEEEEE")
        
        // Hover / Active states
        static let hover = Color(hex: "#E5F0FF")
        static let hoverDark = Color(hex: "#293646")
        
        // 📊 Health Monitor & Graph Visuals
        static let chartCpu = Color(hex: "#5AC8FA") // Light blue
        static let chartMemory = Color(hex: "#34C759") // Apple green
        static let chartDisk = Color(hex: "#FF9500") // Orange
        static let chartNetwork = Color(hex: "#AF52DE") // Purple
        static let chartErrorSpike = Color(hex: "#FF453A") // Red
        
        // Border Colors
        static let border = Color(NSColor.separatorColor)
        static let borderLight = Color(NSColor.separatorColor).opacity(0.5)
        
        // Legacy compatibility
        static let primary = accentPrimary
        static let primaryLight = accentPrimary.opacity(0.1)
        static let primaryDark = accentPrimary.opacity(0.8)
        static let surfaceSecondary = Color(NSColor.secondarySystemFill)
        static let success = statusSuccess
        static let successLight = statusSuccess.opacity(0.1)
        static let warning = statusWarning
        static let warningLight = statusWarning.opacity(0.1)
        static let error = statusError
        static let errorLight = statusError.opacity(0.1)
        static let info = accentPrimary
        static let infoLight = accentPrimary.opacity(0.1)
        static let online = statusSuccess
        static let offline = statusError
        static let syncing = statusSyncing
        static let idle = statusIdle
        static let pressed = Color.gray.opacity(0.2)
        static let selected = accentPrimary.opacity(0.15)
    }
    
    // MARK: - Typography
    struct Typography {
        // Headlines
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let headlineLarge = Font.title.weight(.semibold)
        static let headlineMedium = Font.title2.weight(.semibold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        
        // Body Text
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        static let bodySmall = Font.callout
        static let bodyBold = Font.body.weight(.bold)
        static let callout = Font.callout
        static let calloutMedium = Font.callout.weight(.medium)
        
        // Small Text
        static let caption = Font.caption
        static let captionMedium = Font.caption.weight(.medium)
        static let caption2 = Font.caption2
        static let footnote = Font.footnote
        static let footnoteMedium = Font.footnote.weight(.medium)
        
        // Monospace
        static let mono = Font.system(.body, design: .monospaced)
        static let monoSmall = Font.system(.caption, design: .monospaced)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        
        // Component Spacing
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 20
        static let itemSpacing: CGFloat = 12
        static let buttonSpacing: CGFloat = 8
    }
    
    // MARK: - Layout
    struct Layout {
        static let sidebarWidth: CGFloat = 200
        static let sidebarMinWidth: CGFloat = 150
        static let sidebarMaxWidth: CGFloat = 300
        
        static let cardMinWidth: CGFloat = 280
        static let cardMaxWidth: CGFloat = 400
        static let cardHeight: CGFloat = 120
        
        static let cornerRadius: CGFloat = 12
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusLarge: CGFloat = 16
        
        static let borderWidth: CGFloat = 1
        static let shadowRadius: CGFloat = 8
        static let shadowOpacity: CGFloat = 0.1
    }
    
    // MARK: - Animation
    struct Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let bounce = SwiftUI.Animation.bouncy(duration: 0.4)
    }
    
    // MARK: - Icons
    struct Icons {
        // Status Icons
        static let online = "checkmark.circle.fill"
        static let offline = "xmark.circle.fill"
        static let syncing = "arrow.triangle.2.circlepath"
        static let idle = "circle.fill"
        static let error = "exclamationmark.triangle.fill"
        static let warning = "exclamationmark.circle.fill"
        
        // Navigation Icons
        static let dashboard = "rectangle.grid.2x2"
        static let performance = "chart.line.uptrend.xyaxis"
        static let logs = "doc.text"
        static let settings = "gear"
        static let backup = "externaldrive"
        
        // Action Icons
        static let add = "plus.circle.fill"
        static let edit = "pencil.circle"
        static let delete = "trash.circle"
        static let play = "play.circle.fill"
        static let pause = "pause.circle.fill"
        static let stop = "stop.circle.fill"
        static let refresh = "arrow.clockwise.circle"
        
        // Server Icons
        static let server = "server.rack"
        static let api = "link.circle"
        static let database = "externaldrive.connected.to.line.below"
        static let network = "network"
        static let cloud = "cloud.fill"
        
        // Interface Icons
        static let search = "magnifyingglass"
        static let filter = "line.3.horizontal.decrease.circle"
        static let sort = "arrow.up.arrow.down.circle"
        static let grid = "square.grid.2x2"
        static let list = "list.bullet"
        static let info = "info.circle"
        static let help = "questionmark.circle"
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions
extension View {
    // Card styling
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius))
            .shadow(color: Color.black.opacity(DesignSystem.Layout.shadowOpacity), 
                   radius: DesignSystem.Layout.shadowRadius, x: 0, y: 2)
    }
    
    // Elevated card styling
    func elevatedCardStyle() -> some View {
        self
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius))
            .shadow(color: Color.black.opacity(DesignSystem.Layout.shadowOpacity * 2), 
                   radius: DesignSystem.Layout.shadowRadius * 1.5, x: 0, y: 4)
    }
    
    // Hover effect
    func hoverEffect() -> some View {
        self
            .scaleEffect(1.0)
            .onHover { isHovering in
                withAnimation(DesignSystem.Animation.fast) {
                    // This will be handled by the individual views
                }
            }
    }
    
    // Status indicator
    func statusIndicator(_ status: MCPStatus) -> some View {
        self
            .overlay(
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                    .offset(x: 6, y: -6),
                alignment: .topTrailing
            )
    }
}

// MARK: - MCP Status
enum MCPStatus: String, CaseIterable {
    case online = "online"
    case offline = "offline"
    case syncing = "syncing"
    case idle = "idle"
    case error = "error"
    case warning = "warning"
    
    var color: Color {
        switch self {
        case .online:
            return DesignSystem.Colors.success
        case .offline:
            return DesignSystem.Colors.error
        case .syncing:
            return DesignSystem.Colors.warning
        case .idle:
            return DesignSystem.Colors.idle
        case .error:
            return DesignSystem.Colors.error
        case .warning:
            return DesignSystem.Colors.warning
        }
    }
    
    var icon: String {
        switch self {
        case .online:
            return DesignSystem.Icons.online
        case .offline:
            return DesignSystem.Icons.offline
        case .syncing:
            return DesignSystem.Icons.syncing
        case .idle:
            return DesignSystem.Icons.idle
        case .error:
            return DesignSystem.Icons.error
        case .warning:
            return DesignSystem.Icons.warning
        }
    }
    
    var displayName: String {
        switch self {
        case .online:
            return "Online"
        case .offline:
            return "Offline"
        case .syncing:
            return "Syncing"
        case .idle:
            return "Idle"
        case .error:
            return "Error"
        case .warning:
            return "Warning"
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .fill(DesignSystem.Colors.primary)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .fill(DesignSystem.Colors.surfaceSecondary)
                    .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Layout.borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .padding(DesignSystem.Spacing.sm)
            .background(
                Circle()
                    .fill(configuration.isPressed ? DesignSystem.Colors.pressed : DesignSystem.Colors.hover)
                    .opacity(configuration.isPressed ? 1.0 : 0.0)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: MCPStatus
    let showText: Bool
    
    init(_ status: MCPStatus, showText: Bool = true) {
        self.status = status
        self.showText = showText
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(status.color)
            
            if showText {
                Text(status.displayName)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                .fill(status.color.opacity(0.1))
        )
    }
}

// MARK: - Loading State
struct LoadingView: View {
    let text: String
    
    init(_ text: String = "Loading...") {
        self.text = text
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text(text)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.xxl)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius))
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, subtitle: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: 300)
        .padding(DesignSystem.Spacing.xxxl)
    }
} 