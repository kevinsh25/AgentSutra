import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedCategory: SettingsCategory = .general
    @State private var showingResetAlert = false
    @State private var showingExportPanel = false
    @State private var showingImportPanel = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            // Sidebar
            List(selection: $selectedCategory) {
                Section("Settings") {
                    ForEach(SettingsCategory.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }
            }
            .navigationTitle("Categories")
            .frame(minWidth: 200)
            
            // Main Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCategory.rawValue)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(settingsDescription(for: selectedCategory))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button("Reset") {
                            showingResetAlert = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Export") {
                            showingExportPanel = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Import") {
                            showingImportPanel = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Settings Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        settingsContent(for: selectedCategory)
                    }
                    .padding(20)
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsManager.resetCategory(selectedCategory)
            }
        } message: {
            Text("Are you sure you want to reset all \(selectedCategory.rawValue.lowercased()) settings to their default values?")
        }
        .fileExporter(
            isPresented: $showingExportPanel,
            document: SettingsDocument(data: settingsManager.exportSettings() ?? Data()),
            contentType: .json,
            defaultFilename: "mcp-orchestrator-settings"
        ) { result in
            // Handle export result
        }
        .fileImporter(
            isPresented: $showingImportPanel,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            // Handle import result
        }
    }
    
    // MARK: - Settings Description
    private func settingsDescription(for category: SettingsCategory) -> String {
        switch category {
        case .general:
            return "Configure general application preferences and behavior"
        case .servers:
            return "Manage server configuration, timeouts, and health monitoring"
        case .updates:
            return "Configure automatic updates, channels, and notification preferences"
        case .orchestrator:
            return "Set up orchestrator ports, CORS, rate limiting, and API settings"
        case .performance:
            return "Optimize performance, caching, and resource utilization"
        case .security:
            return "Configure security settings, authentication, and encryption"
        case .logging:
            return "Set up logging levels, formats, and file management"
        case .advanced:
            return "Advanced configuration for developers and power users"
        }
    }
    
    // MARK: - Settings Content
    @ViewBuilder
    private func settingsContent(for category: SettingsCategory) -> some View {
        switch category {
        case .general:
            GeneralSettingsView()
        case .servers:
            ServerSettingsView()
        case .updates:
            UpdateSettingsView()
        case .orchestrator:
            OrchestratorSettingsView()
        case .performance:
            // MARK: - Performance Settings View
            // Note: PerformanceSettingsView is now defined in PerformanceDashboardView.swift
            Text("Performance settings are now managed in the Performance Dashboard")
        case .security:
            SecuritySettingsView()
        case .logging:
            LoggingSettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

// MARK: - General Settings View
struct GeneralSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Startup") {
                Toggle("Launch at startup", isOn: $settingsManager.general.launchAtStartup)
                Toggle("Check for updates on startup", isOn: $settingsManager.general.checkForUpdatesOnStartup)
            }
            
            SettingsGroup("Appearance") {
                HStack {
                    Text("Theme:")
                    Spacer()
                    Picker("Theme", selection: $settingsManager.general.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                Toggle("Show dock icon", isOn: $settingsManager.general.showDockIcon)
                Toggle("Show menu bar icon", isOn: $settingsManager.general.showMenuBarIcon)
                Toggle("Minimize to system tray", isOn: $settingsManager.general.minimizeToTray)
            }
            
            SettingsGroup("Behavior") {
                Toggle("Confirm before quitting", isOn: $settingsManager.general.confirmQuit)
                
                HStack {
                    Text("Language:")
                    Spacer()
                    Picker("Language", selection: $settingsManager.general.language) {
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
        }
        // Auto-save is handled by SettingsManager
    }
}

// MARK: - Server Settings View
struct ServerSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Server Management") {
                Toggle("Auto-start servers", isOn: $settingsManager.servers.autoStartServers)
                Toggle("Enable server logging", isOn: $settingsManager.servers.enableServerLogging)
                Toggle("Enable health checks", isOn: $settingsManager.servers.enableHealthChecks)
                Toggle("Auto-restart failed servers", isOn: $settingsManager.servers.autoRestart)
            }
            
            SettingsGroup("Concurrency & Limits") {
                NumberField(title: "Max concurrent servers", value: $settingsManager.servers.maxConcurrentServers, range: 1...50)
                NumberField(title: "Max restart attempts", value: $settingsManager.servers.maxRestartAttempts, range: 1...10)
                NumberField(title: "Retry attempts", value: $settingsManager.servers.retryAttempts, range: 1...10)
            }
            
            SettingsGroup("Timeouts") {
                TimeIntervalField(title: "Server timeout", value: $settingsManager.servers.serverTimeout)
                TimeIntervalField(title: "Retry delay", value: $settingsManager.servers.retryDelay)
                TimeIntervalField(title: "Health check interval", value: $settingsManager.servers.healthCheckInterval)
            }
        }
        // Auto-save is handled by SettingsManager
    }
}

// MARK: - Update Settings View
struct UpdateSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Automatic Updates") {
                Toggle("Enable automatic updates", isOn: $settingsManager.updates.automaticUpdates)
                Toggle("Download updates automatically", isOn: $settingsManager.updates.downloadUpdatesAutomatically)
                    .disabled(!settingsManager.updates.automaticUpdates)
                Toggle("Install updates automatically", isOn: $settingsManager.updates.installUpdatesAutomatically)
                    .disabled(!settingsManager.updates.automaticUpdates)
            }
            
            SettingsGroup("Update Channel") {
                HStack {
                    Text("Channel:")
                    Spacer()
                    Picker("Channel", selection: $settingsManager.updates.updateChannel) {
                        ForEach(UpdateChannel.allCases, id: \.self) { channel in
                            Text(channel.displayName).tag(channel)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                Toggle("Include beta versions", isOn: $settingsManager.updates.includeBetaVersions)
            }
            
            SettingsGroup("Notifications") {
                Toggle("Notify when updates are available", isOn: $settingsManager.updates.notifyOnUpdateAvailable)
                TimeIntervalField(title: "Check interval", value: $settingsManager.updates.checkInterval)
            }
        }
        // Auto-save is handled by SettingsManager
    }
}

// MARK: - Orchestrator Settings View
struct OrchestratorSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Network") {
                NumberField(title: "Default port", value: $settingsManager.orchestrator.defaultPort, range: 1024...65535)
                NumberField(title: "Metrics port", value: $settingsManager.orchestrator.metricsPort, range: 1024...65535)
                Toggle("Enable CORS", isOn: $settingsManager.orchestrator.enableCORS)
                Toggle("Enable metrics", isOn: $settingsManager.orchestrator.enableMetrics)
            }
            
            SettingsGroup("Rate Limiting") {
                Toggle("Enable rate limiting", isOn: $settingsManager.orchestrator.enableRateLimiting)
                NumberField(title: "Max requests per window", value: $settingsManager.orchestrator.rateLimitRequests, range: 1...10000)
                TimeIntervalField(title: "Rate limit window", value: $settingsManager.orchestrator.rateLimitWindow)
            }
            
            SettingsGroup("API Security") {
                Toggle("Enable API key authentication", isOn: $settingsManager.orchestrator.enableAPIKey)
                
                HStack {
                    Text("API key header:")
                    Spacer()
                    TextField("Header name", text: $settingsManager.orchestrator.apiKeyHeader)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
            }
        }
        // Auto-save is handled by SettingsManager
    }
}

// MARK: - Security Settings View
struct SecuritySettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("TLS/SSL") {
                Toggle("Enable TLS", isOn: $settingsManager.security.enableTLS)
                
                HStack {
                    Text("Certificate path:")
                    Spacer()
                    TextField("Path to certificate", text: $settingsManager.security.tlsCertPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
                
                HStack {
                    Text("Private key path:")
                    Spacer()
                    TextField("Path to private key", text: $settingsManager.security.tlsKeyPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            }
            
            SettingsGroup("Authentication") {
                Toggle("Enable authentication", isOn: $settingsManager.security.enableAuthentication)
                
                HStack {
                    Text("Authentication type:")
                    Spacer()
                    Picker("Auth Type", selection: $settingsManager.security.authType) {
                        ForEach(AuthType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                
                TimeIntervalField(title: "Session timeout", value: $settingsManager.security.sessionTimeout)
            }
            
            SettingsGroup("Encryption") {
                Toggle("Enable encryption", isOn: $settingsManager.security.enableEncryption)
                Toggle("Enable password hashing", isOn: $settingsManager.security.enablePasswordHashing)
                
                HStack {
                    Text("Hash algorithm:")
                    Spacer()
                    Picker("Hash Algorithm", selection: $settingsManager.security.hashAlgorithm) {
                        ForEach(HashAlgorithm.allCases, id: \.self) { algorithm in
                            Text(algorithm.displayName).tag(algorithm)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
            
            SettingsGroup("Audit") {
                Toggle("Enable audit logging", isOn: $settingsManager.security.enableAuditLogging)
            }
        }
        // Auto-save is handled by SettingsManager
    }
}

// MARK: - Logging Settings View
struct LoggingSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Basic Logging") {
                Toggle("Enable logging", isOn: $settingsManager.logging.enableLogging)
                Toggle("Log to file", isOn: $settingsManager.logging.logToFile)
                Toggle("Log to console", isOn: $settingsManager.logging.logToConsole)
                
                HStack {
                    Text("Log level:")
                    Spacer()
                    Picker("Log Level", selection: $settingsManager.logging.logLevel) {
                        ForEach(LogLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
            
            SettingsGroup("Log Format") {
                HStack {
                    Text("Format:")
                    Spacer()
                    Picker("Log Format", selection: $settingsManager.logging.logFormat) {
                        ForEach(LogFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                Toggle("Include timestamps", isOn: $settingsManager.logging.enableTimestamps)
                Toggle("Include source info", isOn: $settingsManager.logging.enableSourceInfo)
            }
            
            SettingsGroup("Log Rotation") {
                Toggle("Enable log rotation", isOn: $settingsManager.logging.logRotation)
                NumberField(title: "Max log files", value: $settingsManager.logging.maxLogFiles, range: 1...100)
                NumberField(title: "Max log size (MB)", value: $settingsManager.logging.maxLogSize, range: 1...1000)
            }
        }
        // Auto-save is handled by SettingsManager
    }
}

// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Developer Options") {
                Toggle("Enable developer mode", isOn: $settingsManager.advanced.enableDeveloperMode)
                Toggle("Enable debug logging", isOn: $settingsManager.advanced.enableDebugLogging)
                Toggle("Enable experimental features", isOn: $settingsManager.advanced.enableExperimentalFeatures)
                Toggle("Enable profiling mode", isOn: $settingsManager.advanced.enableProfilingMode)
            }
            
            SettingsGroup("System") {
                NumberField(title: "Max memory usage (MB)", value: $settingsManager.advanced.maxMemoryUsage, range: 256...8192)
                Toggle("Enable garbage collection", isOn: $settingsManager.advanced.enableGarbageCollection)
                
                HStack {
                    Text("Custom config path:")
                    Spacer()
                    TextField("Path to config", text: $settingsManager.advanced.customConfigPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            }
            
            SettingsGroup("Telemetry") {
                Toggle("Enable telemetry", isOn: $settingsManager.advanced.enableTelemetry)
                
                HStack {
                    Text("Telemetry endpoint:")
                    Spacer()
                    TextField("Endpoint URL", text: $settingsManager.advanced.telemetryEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            }
        }
        // Auto-save is handled by SettingsManager
    }
}

// MARK: - Helper Views
struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(.leading, 16)
        }
    }
}

struct NumberField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Text(title + ":")
            Spacer()
            TextField("", value: $value, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .onChange(of: value) {
                    if !range.contains(value) {
                        value = max(range.lowerBound, min(range.upperBound, value))
                    }
                }
        }
    }
}

struct TimeIntervalField: View {
    let title: String
    @Binding var value: TimeInterval
    
    var body: some View {
        HStack {
            Text(title + ":")
            Spacer()
            TextField("", value: $value, formatter: {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 1
                return formatter
            }())
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            Text("seconds")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Settings Document
struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview
#Preview {
    PreferencesView()
        .frame(width: 800, height: 600)
} 