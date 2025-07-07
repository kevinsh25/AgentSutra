import Foundation
import SwiftUI

// MARK: - Backup Configuration
struct BackupConfiguration: Codable {
    let id = UUID()
    let timestamp: Date
    let version: String
    let name: String
    let description: String
    let settings: BackupSettings
    let servers: [ServerBackup]
    let orchestratorState: OrchestratorStateBackup
    let checksum: String
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var size: String {
        // Calculate estimated size
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self) {
            let bytes = data.count
            if bytes < 1024 {
                return "\(bytes) bytes"
            } else if bytes < 1024 * 1024 {
                return String(format: "%.1f KB", Double(bytes) / 1024)
            } else {
                return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
            }
        }
        return "Unknown"
    }
}

// MARK: - Backup Settings
struct BackupSettings: Codable {
    let includeSettings: Bool
    let includeServerConfigs: Bool
    let includeOrchestratorState: Bool
    let includeSecrets: Bool // Note: Actual secrets would be encrypted
    let compressionEnabled: Bool
    let encryptionEnabled: Bool
}

// MARK: - Server Backup
struct ServerBackup: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let enabled: Bool
    let configuration: [String: String]
    let metadata: ServerMetadata
    let lastHealthCheck: Date?
    let statistics: ServerStatistics?
}

// MARK: - Server Metadata
struct ServerMetadata: Codable {
    let version: String
    let type: String
    let installationDate: Date
    let lastUpdate: Date?
    let customizations: [String: String]
}

// MARK: - Server Statistics
struct ServerStatistics: Codable {
    let totalRequests: Int
    let successfulRequests: Int
    let failedRequests: Int
    let averageResponseTime: Double
    let lastRequestTime: Date?
    let uptime: TimeInterval
}

// MARK: - Orchestrator State Backup
struct OrchestratorStateBackup: Codable {
    let activeServers: [String]
    let queuedTasks: [TaskBackup]
    let systemMetrics: SystemMetricsBackup
    let userPreferences: [String: String]
    let cacheState: CacheStateBackup
}

// MARK: - Task Backup
struct TaskBackup: Codable {
    let id: String
    let type: String
    let status: String
    let createdAt: Date
    let parameters: [String: String]
}

// MARK: - System Metrics Backup
struct SystemMetricsBackup: Codable {
    let memoryUsage: Double
    let cpuUsage: Double
    let diskUsage: Double
    let networkActivity: Double
    let recordedAt: Date
}

// MARK: - Cache State Backup
struct CacheStateBackup: Codable {
    let size: Int
    let hitRate: Double
    let missRate: Double
    let lastCleared: Date?
}

// MARK: - Backup Manager
class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    @Published var availableBackups: [BackupConfiguration] = []
    @Published var isCreatingBackup = false
    @Published var isRestoringBackup = false
    @Published var lastBackupDate: Date?
    @Published var autoBackupEnabled = true
    @Published var autoBackupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private let fileManager = FileManager.default
    private let loggingManager = SimpleLoggingManager.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var backupDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backupDir = appSupport.appendingPathComponent("MCPOrchestrator/Backups")
        try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        return backupDir
    }
    
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadAvailableBackups()
        setupAutoBackup()
    }
    
    // MARK: - Backup Creation
    func createBackup(name: String, description: String, settings: BackupSettings) async -> Result<BackupConfiguration, BackupError> {
        DispatchQueue.main.async {
            self.isCreatingBackup = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isCreatingBackup = false
            }
        }
        
        do {
            loggingManager.info("Creating backup: \(name)", category: .general)
            
            // Collect server configurations
            let servers = await collectServerConfigurations()
            
            // Collect orchestrator state
            let orchestratorState = await collectOrchestratorState()
            
            // Create backup configuration
            let backup = BackupConfiguration(
                timestamp: Date(),
                version: "1.0.0", // App version
                name: name,
                description: description,
                settings: settings,
                servers: servers,
                orchestratorState: orchestratorState,
                checksum: "" // Will be calculated
            )
            
            // Calculate checksum
            let backupWithChecksum = calculateChecksum(for: backup)
            
            // Save to file
            let filename = "backup_\(ISO8601DateFormatter().string(from: backup.timestamp)).json"
            let backupURL = backupDirectory.appendingPathComponent(filename)
            
            let data = try encoder.encode(backupWithChecksum)
            try data.write(to: backupURL)
            
            DispatchQueue.main.async {
                self.availableBackups.append(backupWithChecksum)
                self.availableBackups.sort { $0.timestamp > $1.timestamp }
                self.lastBackupDate = Date()
            }
            
            loggingManager.info("Backup created successfully: \(filename)", category: .general)
            return .success(backupWithChecksum)
            
        } catch {
            loggingManager.error("Failed to create backup: \(error.localizedDescription)", category: .general)
            return .failure(.creationFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Backup Restoration
    func restoreBackup(_ backup: BackupConfiguration, options: RestoreOptions) async -> Result<Void, BackupError> {
        DispatchQueue.main.async {
            self.isRestoringBackup = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isRestoringBackup = false
            }
        }
        
        do {
            loggingManager.info("Restoring backup: \(backup.name)", category: .general)
            
            // Verify backup integrity
            if !verifyBackupIntegrity(backup) {
                return .failure(.corruptedBackup)
            }
            
            // Create restoration point before proceeding
            let restorationPoint = await createRestorePoint()
            
            // Restore components based on options
            if options.restoreSettings {
                try await restoreSettings(from: backup)
            }
            
            if options.restoreServerConfigs {
                try await restoreServerConfigurations(from: backup)
            }
            
            if options.restoreOrchestratorState {
                try await restoreOrchestratorState(from: backup)
            }
            
            loggingManager.info("Backup restored successfully: \(backup.name)", category: .general)
            return .success(())
            
        } catch {
            loggingManager.error("Failed to restore backup: \(error.localizedDescription)", category: .general)
            
            // Attempt to restore from restoration point
            // await restoreFromRestorePoint(restorationPoint)
            
            return .failure(.restorationFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Backup Management
    func deleteBackup(_ backup: BackupConfiguration) {
        do {
            let filename = "backup_\(ISO8601DateFormatter().string(from: backup.timestamp)).json"
            let backupURL = backupDirectory.appendingPathComponent(filename)
            try fileManager.removeItem(at: backupURL)
            
            if let index = availableBackups.firstIndex(where: { $0.id == backup.id }) {
                availableBackups.remove(at: index)
            }
            
            loggingManager.info("Backup deleted: \(backup.name)", category: .general)
        } catch {
            loggingManager.error("Failed to delete backup: \(error.localizedDescription)", category: .general)
        }
    }
    
    func exportBackup(_ backup: BackupConfiguration) -> URL? {
        do {
            let filename = "\(backup.name.replacingOccurrences(of: " ", with: "_"))_\(ISO8601DateFormatter().string(from: backup.timestamp)).mcpbackup"
            let tempURL = fileManager.temporaryDirectory.appendingPathComponent(filename)
            
            let data = try encoder.encode(backup)
            try data.write(to: tempURL)
            
            loggingManager.info("Backup exported: \(filename)", category: .general)
            return tempURL
        } catch {
            loggingManager.error("Failed to export backup: \(error.localizedDescription)", category: .general)
            return nil
        }
    }
    
    func importBackup(from url: URL) async -> Result<BackupConfiguration, BackupError> {
        do {
            let data = try Data(contentsOf: url)
            let backup = try decoder.decode(BackupConfiguration.self, from: data)
            
            // Verify backup integrity
            if !verifyBackupIntegrity(backup) {
                return .failure(.corruptedBackup)
            }
            
            // Save to local backup directory
            let filename = "backup_\(ISO8601DateFormatter().string(from: backup.timestamp)).json"
            let backupURL = backupDirectory.appendingPathComponent(filename)
            try data.write(to: backupURL)
            
            DispatchQueue.main.async {
                self.availableBackups.append(backup)
                self.availableBackups.sort { $0.timestamp > $1.timestamp }
            }
            
            loggingManager.info("Backup imported successfully: \(backup.name)", category: .general)
            return .success(backup)
            
        } catch {
            loggingManager.error("Failed to import backup: \(error.localizedDescription)", category: .general)
            return .failure(.importFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Auto Backup
    private func setupAutoBackup() {
        guard autoBackupEnabled else { return }
        
        Timer.scheduledTimer(withTimeInterval: autoBackupInterval, repeats: true) { _ in
            Task {
                await self.performAutoBackup()
            }
        }
    }
    
    private func performAutoBackup() async {
        let settings = BackupSettings(
            includeSettings: true,
            includeServerConfigs: true,
            includeOrchestratorState: true,
            includeSecrets: false,
            compressionEnabled: true,
            encryptionEnabled: false
        )
        
        let name = "Auto Backup"
        let description = "Automatically created backup"
        
        let result = await createBackup(name: name, description: description, settings: settings)
        
        switch result {
        case .success:
            loggingManager.info("Auto backup completed successfully", category: .general)
            
            // Clean up old auto backups (keep only last 10)
            let autoBackups = availableBackups.filter { $0.name == "Auto Backup" }
            if autoBackups.count > 10 {
                let oldBackups = Array(autoBackups.dropFirst(10))
                for backup in oldBackups {
                    deleteBackup(backup)
                }
            }
            
        case .failure(let error):
            loggingManager.error("Auto backup failed: \(error.localizedDescription)", category: .general)
        }
    }
    
    // MARK: - Data Collection
    private func collectServerConfigurations() async -> [ServerBackup] {
        // This would normally collect from the actual server configurations
        // For demo purposes, creating sample data
        return [
            ServerBackup(
                id: "github-server",
                name: "GitHub Server",
                category: "Development",
                enabled: true,
                configuration: [
                    "api_url": "https://api.github.com",
                    "timeout": "30",
                    "max_retries": "3"
                ],
                metadata: ServerMetadata(
                    version: "1.2.0",
                    type: "REST API",
                    installationDate: Date().addingTimeInterval(-86400 * 30),
                    lastUpdate: Date().addingTimeInterval(-86400 * 7),
                    customizations: ["theme": "dark", "notifications": "enabled"]
                ),
                lastHealthCheck: Date(),
                statistics: ServerStatistics(
                    totalRequests: 1250,
                    successfulRequests: 1180,
                    failedRequests: 70,
                    averageResponseTime: 245.5,
                    lastRequestTime: Date(),
                    uptime: 86400 * 25
                )
            ),
            ServerBackup(
                id: "slack-server",
                name: "Slack Server",
                category: "Communication",
                enabled: true,
                configuration: [
                    "workspace": "company.slack.com",
                    "bot_token": "[ENCRYPTED]",
                    "channel_limit": "50"
                ],
                metadata: ServerMetadata(
                    version: "2.1.0",
                    type: "WebSocket",
                    installationDate: Date().addingTimeInterval(-86400 * 60),
                    lastUpdate: Date().addingTimeInterval(-86400 * 14),
                    customizations: ["auto_join": "true", "message_history": "7d"]
                ),
                lastHealthCheck: Date(),
                statistics: ServerStatistics(
                    totalRequests: 3420,
                    successfulRequests: 3350,
                    failedRequests: 70,
                    averageResponseTime: 120.3,
                    lastRequestTime: Date(),
                    uptime: 86400 * 58
                )
            )
        ]
    }
    
    private func collectOrchestratorState() async -> OrchestratorStateBackup {
        return OrchestratorStateBackup(
            activeServers: ["github-server", "slack-server"],
            queuedTasks: [
                TaskBackup(
                    id: "task-1",
                    type: "health_check",
                    status: "pending",
                    createdAt: Date(),
                    parameters: ["server_id": "github-server"]
                )
            ],
            systemMetrics: SystemMetricsBackup(
                memoryUsage: 45.6,
                cpuUsage: 12.3,
                diskUsage: 67.8,
                networkActivity: 89.2,
                recordedAt: Date()
            ),
            userPreferences: [
                "theme": "dark",
                "auto_refresh": "true",
                "notification_sound": "enabled"
            ],
            cacheState: CacheStateBackup(
                size: 1024 * 1024 * 50, // 50MB
                hitRate: 0.85,
                missRate: 0.15,
                lastCleared: Date().addingTimeInterval(-86400)
            )
        )
    }
    
    // MARK: - Utility Methods
    private func calculateChecksum(for backup: BackupConfiguration) -> BackupConfiguration {
        // Simple checksum calculation (in production, use proper cryptographic hash)
        let backupString = "\(backup.timestamp)\(backup.name)\(backup.servers.count)\(backup.orchestratorState.activeServers.count)"
        let checksum = String(backupString.hashValue)
        
        return BackupConfiguration(
            timestamp: backup.timestamp,
            version: backup.version,
            name: backup.name,
            description: backup.description,
            settings: backup.settings,
            servers: backup.servers,
            orchestratorState: backup.orchestratorState,
            checksum: checksum
        )
    }
    
    private func verifyBackupIntegrity(_ backup: BackupConfiguration) -> Bool {
        let backupString = "\(backup.timestamp)\(backup.name)\(backup.servers.count)\(backup.orchestratorState.activeServers.count)"
        let expectedChecksum = String(backupString.hashValue)
        return backup.checksum == expectedChecksum
    }
    
    private func loadAvailableBackups() {
        do {
            let backupFiles = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
            
            for file in backupFiles.filter({ $0.pathExtension == "json" }) {
                if let data = try? Data(contentsOf: file),
                   let backup = try? decoder.decode(BackupConfiguration.self, from: data) {
                    availableBackups.append(backup)
                }
            }
            
            availableBackups.sort { $0.timestamp > $1.timestamp }
            
            if let latest = availableBackups.first {
                lastBackupDate = latest.timestamp
            }
            
        } catch {
            loggingManager.error("Failed to load available backups: \(error.localizedDescription)", category: .general)
        }
    }
    
    private func createRestorePoint() async -> BackupConfiguration? {
        let settings = BackupSettings(
            includeSettings: true,
            includeServerConfigs: true,
            includeOrchestratorState: true,
            includeSecrets: false,
            compressionEnabled: false,
            encryptionEnabled: false
        )
        
        let result = await createBackup(
            name: "Restoration Point",
            description: "Automatic backup created before restoration",
            settings: settings
        )
        
        switch result {
        case .success(let backup):
            return backup
        case .failure:
            return nil
        }
    }
    
    private func restoreSettings(from backup: BackupConfiguration) async throws {
        // Restore application settings
        loggingManager.info("Restoring settings from backup", category: .general)
        // Implementation would restore actual settings
    }
    
    private func restoreServerConfigurations(from backup: BackupConfiguration) async throws {
        // Restore server configurations
        loggingManager.info("Restoring server configurations from backup", category: .server)
        // Implementation would restore actual server configs
    }
    
    private func restoreOrchestratorState(from backup: BackupConfiguration) async throws {
        // Restore orchestrator state
        loggingManager.info("Restoring orchestrator state from backup", category: .general)
        // Implementation would restore actual orchestrator state
    }
}

// MARK: - Backup Error
enum BackupError: LocalizedError {
    case creationFailed(String)
    case restorationFailed(String)
    case corruptedBackup
    case importFailed(String)
    case exportFailed(String)
    case insufficientPermissions
    case diskSpaceFull
    
    var errorDescription: String? {
        switch self {
        case .creationFailed(let details):
            return "Failed to create backup: \(details)"
        case .restorationFailed(let details):
            return "Failed to restore backup: \(details)"
        case .corruptedBackup:
            return "Backup file is corrupted or invalid"
        case .importFailed(let details):
            return "Failed to import backup: \(details)"
        case .exportFailed(let details):
            return "Failed to export backup: \(details)"
        case .insufficientPermissions:
            return "Insufficient permissions to access backup location"
        case .diskSpaceFull:
            return "Insufficient disk space to create backup"
        }
    }
}

// MARK: - Restore Options
struct RestoreOptions: Codable {
    let restoreSettings: Bool
    let restoreServerConfigs: Bool
    let restoreOrchestratorState: Bool
    let overwriteExisting: Bool
    let createBackupBeforeRestore: Bool
    
    static let `default` = RestoreOptions(
        restoreSettings: true,
        restoreServerConfigs: true,
        restoreOrchestratorState: true,
        overwriteExisting: true,
        createBackupBeforeRestore: true
    )
} 