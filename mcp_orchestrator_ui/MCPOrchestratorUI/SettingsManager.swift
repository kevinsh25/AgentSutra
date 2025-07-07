import SwiftUI
import Foundation

// MARK: - Settings Categories
enum SettingsCategory: String, CaseIterable {
    case general = "General"
    case servers = "Servers"
    case updates = "Updates"
    case orchestrator = "Orchestrator"
    case performance = "Performance"
    case security = "Security"
    case logging = "Logging"
    case advanced = "Advanced"
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .servers: return "server.rack"
        case .updates: return "arrow.triangle.2.circlepath"
        case .orchestrator: return "music.mic"
        case .performance: return "speedometer"
        case .security: return "lock.shield"
        case .logging: return "doc.text"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Settings Models
struct GeneralSettings: Codable {
    var launchAtStartup: Bool = false
    var startMinimized: Bool = false
    var showDockIcon: Bool = true
    var showMenuBarIcon: Bool = true
    var minimizeToTray: Bool = false
    var confirmQuit: Bool = true
    var theme: AppTheme = .system
    var language: String = "en"
    var checkForUpdatesOnStartup: Bool = true
}

struct ServerSettings: Codable {
    var autoStartServers: Bool = true
    var maxConcurrentServers: Int = 10
    var serverTimeout: TimeInterval = 30.0
    var retryAttempts: Int = 3
    var retryDelay: TimeInterval = 5.0
    var enableHealthChecks: Bool = true
    var healthCheckInterval: TimeInterval = 60.0
    var autoRestart: Bool = true
    var maxRestartAttempts: Int = 5
    var enableServerLogging: Bool = true
}

struct UpdateSettings: Codable {
    var automaticUpdates: Bool = true
    var checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    var downloadUpdatesAutomatically: Bool = false
    var installUpdatesAutomatically: Bool = false
    var includeBetaVersions: Bool = false
    var notifyOnUpdateAvailable: Bool = true
    var updateChannel: UpdateChannel = .stable
}

struct OrchestratorSettings: Codable {
    var defaultPort: Int = 8080
    var enableCORS: Bool = true
    var corsOrigins: [String] = ["*"]
    var enableRateLimiting: Bool = true
    var rateLimitRequests: Int = 100
    var rateLimitWindow: TimeInterval = 60.0
    var enableMetrics: Bool = true
    var metricsPort: Int = 9090
    var enableAPIKey: Bool = false
    var apiKeyHeader: String = "X-API-Key"
}

struct PerformanceSettings: Codable {
    var maxWorkerThreads: Int = 4
    var requestTimeout: TimeInterval = 30.0
    var keepAliveTimeout: TimeInterval = 5.0
    var maxQueueSize: Int = 1000
    var enableCaching: Bool = true
    var cacheSize: Int = 100 // MB
    var cacheTTL: TimeInterval = 3600 // 1 hour
    var enableCompression: Bool = true
    var compressionLevel: Int = 6
    var enableConnectionPooling: Bool = true
}

struct SecuritySettings: Codable {
    var enableTLS: Bool = false
    var tlsCertPath: String = ""
    var tlsKeyPath: String = ""
    var enableAuthentication: Bool = false
    var authType: AuthType = .apiKey
    var sessionTimeout: TimeInterval = 24 * 60 * 60 // 24 hours
    var enablePasswordHashing: Bool = true
    var hashAlgorithm: HashAlgorithm = .sha256
    var enableEncryption: Bool = true
    var encryptionKey: String = ""
    var enableAuditLogging: Bool = false
}

struct LoggingSettings: Codable {
    var enableLogging: Bool = true
    var logLevel: LogLevel = .info
    var logToFile: Bool = true
    var logToConsole: Bool = true
    var logRotation: Bool = true
    var maxLogFiles: Int = 10
    var maxLogSize: Int = 10 // MB
    var logFormat: LogFormat = .json
    var enableTimestamps: Bool = true
    var enableSourceInfo: Bool = false
}

struct AdvancedSettings: Codable {
    var enableDeveloperMode: Bool = false
    var enableDebugLogging: Bool = false
    var enableExperimentalFeatures: Bool = false
    var customConfigPath: String = ""
    var enableTelemetry: Bool = true
    var telemetryEndpoint: String = ""
    var enableProfilingMode: Bool = false
    var maxMemoryUsage: Int = 1024 // MB
    var enableGarbageCollection: Bool = true
}

// MARK: - Supporting Enums
enum AppTheme: String, CaseIterable, Codable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var displayName: String { rawValue }
}

enum UpdateChannel: String, CaseIterable, Codable {
    case stable = "Stable"
    case beta = "Beta"
    case nightly = "Nightly"
    
    var displayName: String { rawValue }
}

enum AuthType: String, CaseIterable, Codable {
    case none = "None"
    case apiKey = "API Key"
    case basic = "Basic Auth"
    case bearer = "Bearer Token"
    case oauth = "OAuth"
    
    var displayName: String { rawValue }
}

enum HashAlgorithm: String, CaseIterable, Codable {
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"
    case bcrypt = "bcrypt"
    
    var displayName: String { rawValue }
}

enum LogFormat: String, CaseIterable, Codable {
    case text = "Text"
    case json = "JSON"
    case structured = "Structured"
    
    var displayName: String { rawValue }
}

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var general = GeneralSettings()
    @Published var servers = ServerSettings()
    @Published var updates = UpdateSettings()
    @Published var orchestrator = OrchestratorSettings()
    @Published var performance = PerformanceSettings()
    @Published var security = SecuritySettings()
    @Published var logging = LoggingSettings()
    @Published var advanced = AdvancedSettings()
    
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Load Settings
    func loadSettings() {
        loadGeneralSettings()
        loadServerSettings()
        loadUpdateSettings()
        loadOrchestratorSettings()
        loadPerformanceSettings()
        loadSecuritySettings()
        loadLoggingSettings()
        loadAdvancedSettings()
    }
    
    private func loadGeneralSettings() {
        if let data = userDefaults.data(forKey: "GeneralSettings"),
           let settings = try? decoder.decode(GeneralSettings.self, from: data) {
            self.general = settings
        }
    }
    
    private func loadServerSettings() {
        if let data = userDefaults.data(forKey: "ServerSettings"),
           let settings = try? decoder.decode(ServerSettings.self, from: data) {
            self.servers = settings
        }
    }
    
    private func loadUpdateSettings() {
        if let data = userDefaults.data(forKey: "UpdateSettings"),
           let settings = try? decoder.decode(UpdateSettings.self, from: data) {
            self.updates = settings
        }
    }
    
    private func loadOrchestratorSettings() {
        if let data = userDefaults.data(forKey: "OrchestratorSettings"),
           let settings = try? decoder.decode(OrchestratorSettings.self, from: data) {
            self.orchestrator = settings
        }
    }
    
    private func loadPerformanceSettings() {
        if let data = userDefaults.data(forKey: "PerformanceSettings"),
           let settings = try? decoder.decode(PerformanceSettings.self, from: data) {
            self.performance = settings
        }
    }
    
    private func loadSecuritySettings() {
        if let data = userDefaults.data(forKey: "SecuritySettings"),
           let settings = try? decoder.decode(SecuritySettings.self, from: data) {
            self.security = settings
        }
    }
    
    private func loadLoggingSettings() {
        if let data = userDefaults.data(forKey: "LoggingSettings"),
           let settings = try? decoder.decode(LoggingSettings.self, from: data) {
            self.logging = settings
        }
    }
    
    private func loadAdvancedSettings() {
        if let data = userDefaults.data(forKey: "AdvancedSettings"),
           let settings = try? decoder.decode(AdvancedSettings.self, from: data) {
            self.advanced = settings
        }
    }
    
    // MARK: - Save Settings
    func saveSettings() {
        saveGeneralSettings()
        saveServerSettings()
        saveUpdateSettings()
        saveOrchestratorSettings()
        savePerformanceSettings()
        saveSecuritySettings()
        saveLoggingSettings()
        saveAdvancedSettings()
    }
    
    private func saveGeneralSettings() {
        if let data = try? encoder.encode(general) {
            userDefaults.set(data, forKey: "GeneralSettings")
        }
    }
    
    private func saveServerSettings() {
        if let data = try? encoder.encode(servers) {
            userDefaults.set(data, forKey: "ServerSettings")
        }
    }
    
    private func saveUpdateSettings() {
        if let data = try? encoder.encode(updates) {
            userDefaults.set(data, forKey: "UpdateSettings")
        }
    }
    
    private func saveOrchestratorSettings() {
        if let data = try? encoder.encode(orchestrator) {
            userDefaults.set(data, forKey: "OrchestratorSettings")
        }
    }
    
    private func savePerformanceSettings() {
        if let data = try? encoder.encode(performance) {
            userDefaults.set(data, forKey: "PerformanceSettings")
        }
    }
    
    private func saveSecuritySettings() {
        if let data = try? encoder.encode(security) {
            userDefaults.set(data, forKey: "SecuritySettings")
        }
    }
    
    private func saveLoggingSettings() {
        if let data = try? encoder.encode(logging) {
            userDefaults.set(data, forKey: "LoggingSettings")
        }
    }
    
    private func saveAdvancedSettings() {
        if let data = try? encoder.encode(advanced) {
            userDefaults.set(data, forKey: "AdvancedSettings")
        }
    }
    
    // MARK: - Reset Settings
    func resetSettings() {
        general = GeneralSettings()
        servers = ServerSettings()
        updates = UpdateSettings()
        orchestrator = OrchestratorSettings()
        performance = PerformanceSettings()
        security = SecuritySettings()
        logging = LoggingSettings()
        advanced = AdvancedSettings()
        
        saveSettings()
    }
    
    func resetCategory(_ category: SettingsCategory) {
        switch category {
        case .general:
            general = GeneralSettings()
            saveGeneralSettings()
        case .servers:
            servers = ServerSettings()
            saveServerSettings()
        case .updates:
            updates = UpdateSettings()
            saveUpdateSettings()
        case .orchestrator:
            orchestrator = OrchestratorSettings()
            saveOrchestratorSettings()
        case .performance:
            performance = PerformanceSettings()
            savePerformanceSettings()
        case .security:
            security = SecuritySettings()
            saveSecuritySettings()
        case .logging:
            logging = LoggingSettings()
            saveLoggingSettings()
        case .advanced:
            advanced = AdvancedSettings()
            saveAdvancedSettings()
        }
    }
    
    // MARK: - Export/Import
    func exportSettings() -> Data? {
        let allSettings: [String: Any] = [
            "general": general,
            "servers": servers,
            "updates": updates,
            "orchestrator": orchestrator,
            "performance": performance,
            "security": security,
            "logging": logging,
            "advanced": advanced
        ]
        
        return try? JSONSerialization.data(withJSONObject: allSettings, options: .prettyPrinted)
    }
    
    func importSettings(from data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SettingsError.invalidFormat
        }
        
        // Parse and load each category
        if let generalData = json["general"] as? [String: Any],
           let generalJSON = try? JSONSerialization.data(withJSONObject: generalData),
           let generalSettings = try? decoder.decode(GeneralSettings.self, from: generalJSON) {
            self.general = generalSettings
        }
        
        if let serversData = json["servers"] as? [String: Any],
           let serversJSON = try? JSONSerialization.data(withJSONObject: serversData),
           let serversSettings = try? decoder.decode(ServerSettings.self, from: serversJSON) {
            self.servers = serversSettings
        }
        
        // Continue for other categories...
        saveSettings()
    }
}

// MARK: - Settings Error
enum SettingsError: Error {
    case invalidFormat
    case encodingError
    case decodingError
    case fileNotFound
    case accessDenied
    
    var localizedDescription: String {
        switch self {
        case .invalidFormat:
            return "Invalid settings file format"
        case .encodingError:
            return "Failed to encode settings"
        case .decodingError:
            return "Failed to decode settings"
        case .fileNotFound:
            return "Settings file not found"
        case .accessDenied:
            return "Access denied to settings file"
        }
    }
} 