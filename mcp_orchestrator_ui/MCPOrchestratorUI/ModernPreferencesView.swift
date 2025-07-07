import SwiftUI

// MARK: - Modern Preferences View
struct ModernPreferencesView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: PreferencesCategory = .general
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            HSplitView {
                // Sidebar
                sidebarView
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
                
                // Content
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 800, height: 600)
        .background(DesignSystem.Colors.surface)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // Window Controls Space
            HStack {
                Circle().fill(Color.clear).frame(width: 12, height: 12)
                Circle().fill(Color.clear).frame(width: 12, height: 12)
                Circle().fill(Color.clear).frame(width: 12, height: 12)
            }
            .padding(.leading, DesignSystem.Spacing.md)
            
            Spacer()
            
            // Title
            Text("Settings")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            // Close Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, DesignSystem.Spacing.md)
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surfaceElevated)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignSystem.Colors.border),
            alignment: .bottom
        )
    }
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search
            HStack {
                Image(systemName: DesignSystem.Icons.search)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                TextField("Search settings...", text: $searchText)
                    .font(DesignSystem.Typography.body)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.surfaceSecondary)
            .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            
            // Categories
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(PreferencesCategory.allCases) { category in
                        if searchText.isEmpty || category.searchableText.localizedCaseInsensitiveContains(searchText) {
                            PreferencesCategoryRow(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(DesignSystem.Animation.fast) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.lg)
            }
            
            Spacer()
        }
        .background(DesignSystem.Colors.surfaceElevated)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignSystem.Colors.border),
            alignment: .trailing
        )
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionSpacing) {
                // Category Header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Image(systemName: selectedCategory.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(selectedCategory.color)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(selectedCategory.rawValue)
                                .font(DesignSystem.Typography.title)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text(selectedCategory.description)
                                .font(DesignSystem.Typography.callout)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                }
                
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.sm)
                
                // Category Content
                selectedCategoryContent
            }
            .padding(DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.surface)
    }
    
    // MARK: - Category Content
    @ViewBuilder
    private var selectedCategoryContent: some View {
        switch selectedCategory {
        case .general:
            generalSettings
        case .servers:
            serverSettings
        case .performance:
            performanceSettings
        case .appearance:
            appearanceSettings
        case .advanced:
            advancedSettings
        }
    }
    
    // MARK: - General Settings
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionSpacing) {
            PreferencesSection("Startup & Launch") {
                SettingsToggle(
                    title: "Launch at login",
                    subtitle: "Automatically start MCP Orchestrator when you log in",
                    isOn: $settingsManager.general.launchAtStartup
                )
                
                SettingsToggle(
                    title: "Start minimized",
                    subtitle: "Open in the background when launching at login",
                    isOn: $settingsManager.general.startMinimized
                )
                
                SettingsToggle(
                    title: "Show in dock",
                    subtitle: "Display app icon in the dock",
                    isOn: $settingsManager.general.showDockIcon
                )
                
                SettingsToggle(
                    title: "Show in menu bar",
                    subtitle: "Display a menu bar icon for quick access",
                    isOn: $settingsManager.general.showMenuBarIcon
                )
            }
            
            PreferencesSection("Behavior") {
                SettingsToggle(
                    title: "Confirm before quitting",
                    subtitle: "Show confirmation dialog when quitting the app",
                    isOn: $settingsManager.general.confirmQuit
                )
                
                SettingsToggle(
                    title: "Minimize to tray",
                    subtitle: "Hide to menu bar instead of dock when minimizing",
                    isOn: $settingsManager.general.minimizeToTray
                )
            }
            
            PreferencesSection("Updates") {
                SettingsToggle(
                    title: "Check for updates automatically",
                    subtitle: "Automatically check for app updates on startup",
                    isOn: $settingsManager.general.checkForUpdatesOnStartup
                )
                
                HStack {
                    Button("Check for Updates") {
                        // Implement update check
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Server Settings
    private var serverSettings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionSpacing) {
            PreferencesSection("Default Configuration") {
                SettingsRow(title: "Default timeout", subtitle: "Default timeout for server connections") {
                    TextField("30", text: .constant("30"))
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("seconds")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                SettingsRow(title: "Max retries", subtitle: "Maximum number of connection retries") {
                    TextField("3", text: .constant("3"))
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                SettingsToggle(
                    title: "Auto-start servers",
                    subtitle: "Automatically start servers when the app launches",
                    isOn: .constant(true)
                )
            }
            
            PreferencesSection("Health Monitoring") {
                SettingsRow(title: "Check interval", subtitle: "How often to check server health") {
                    Picker("", selection: .constant(30)) {
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                }
                
                SettingsToggle(
                    title: "Show notifications",
                    subtitle: "Display notifications for server status changes",
                    isOn: .constant(true)
                )
            }
        }
    }
    
    // MARK: - Performance Settings
    private var performanceSettings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionSpacing) {
            PreferencesSection("Monitoring") {
                SettingsToggle(
                    title: "Enable performance monitoring",
                    subtitle: "Track CPU, memory, and network usage",
                    isOn: .constant(true)
                )
                
                SettingsRow(title: "Data retention", subtitle: "How long to keep performance data") {
                    Picker("", selection: .constant(7)) {
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                }
            }
            
            PreferencesSection("Alerts") {
                SettingsRow(title: "High CPU threshold", subtitle: "Alert when CPU usage exceeds") {
                    TextField("80", text: .constant("80"))
                        .frame(width: 50)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("%")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                SettingsRow(title: "High memory threshold", subtitle: "Alert when memory usage exceeds") {
                    TextField("85", text: .constant("85"))
                        .frame(width: 50)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("%")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Appearance Settings
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionSpacing) {
            PreferencesSection("Theme") {
                SettingsRow(title: "Appearance", subtitle: "Choose your preferred theme") {
                    Picker("", selection: .constant("system")) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                }
            }
            
            PreferencesSection("Interface") {
                SettingsToggle(
                    title: "Show sidebar",
                    subtitle: "Display the sidebar navigation by default",
                    isOn: .constant(true)
                )
                
                SettingsToggle(
                    title: "Compact mode",
                    subtitle: "Use smaller interface elements",
                    isOn: .constant(false)
                )
                
                SettingsRow(title: "Default view", subtitle: "Default layout for server list") {
                    Picker("", selection: .constant("grid")) {
                        Text("Grid").tag("grid")
                        Text("List").tag("list")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 140)
                }
            }
        }
    }
    
    // MARK: - Advanced Settings
    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionSpacing) {
            PreferencesSection("Logging") {
                SettingsRow(title: "Log level", subtitle: "Minimum level for log messages") {
                    Picker("", selection: .constant("info")) {
                        Text("Debug").tag("debug")
                        Text("Info").tag("info")
                        Text("Warning").tag("warning")
                        Text("Error").tag("error")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 100)
                }
                
                SettingsToggle(
                    title: "Enable file logging",
                    subtitle: "Save logs to files for debugging",
                    isOn: .constant(true)
                )
            }
            
            PreferencesSection("Data & Privacy") {
                SettingsToggle(
                    title: "Collect analytics",
                    subtitle: "Help improve the app by sharing usage data",
                    isOn: .constant(false)
                )
                
                SettingsToggle(
                    title: "Send crash reports",
                    subtitle: "Automatically send crash reports to developers",
                    isOn: .constant(true)
                )
            }
            
            PreferencesSection("Reset") {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Reset all settings to their default values. This action cannot be undone.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    HStack {
                        Button("Reset All Settings") {
                            settingsManager.resetSettings()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Preferences Category
enum PreferencesCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case servers = "Servers"
    case performance = "Performance"
    case appearance = "Appearance"
    case advanced = "Advanced"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .servers: return "server.rack"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .appearance: return "paintbrush"
        case .advanced: return "terminal"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return DesignSystem.Colors.primary
        case .servers: return DesignSystem.Colors.success
        case .performance: return DesignSystem.Colors.warning
        case .appearance: return DesignSystem.Colors.info
        case .advanced: return DesignSystem.Colors.error
        }
    }
    
    var description: String {
        switch self {
        case .general: return "Basic app settings and behavior"
        case .servers: return "Default server configuration and monitoring"
        case .performance: return "Performance monitoring and alerts"
        case .appearance: return "Theme and interface customization"
        case .advanced: return "Logging, debugging, and data settings"
        }
    }
    
    var searchableText: String {
        return rawValue + " " + description
    }
}

// MARK: - Preferences Category Row
struct PreferencesCategoryRow: View {
    let category: PreferencesCategory
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? category.color : DesignSystem.Colors.textSecondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(category.rawValue)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                    
                    Text(category.description)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .fill(isSelected ? category.color.opacity(0.1) : (isHovering ? DesignSystem.Colors.hover : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .stroke(isSelected ? category.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(DesignSystem.Animation.fast, value: isSelected)
        .animation(DesignSystem.Animation.fast, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Preferences Section
struct PreferencesSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text(title)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                content
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.surfaceElevated)
            .cornerRadius(DesignSystem.Layout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Layout.borderWidth)
            )
        }
    }
}

// MARK: - Settings Toggle
struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
        }
    }
}

// MARK: - Settings Row
struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    
    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            content
        }
    }
}

// MARK: - Preview
struct ModernPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        ModernPreferencesView()
            .preferredColorScheme(.light)
    }
} 