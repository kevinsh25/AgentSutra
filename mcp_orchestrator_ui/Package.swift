// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MCPOrchestratorUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MCPOrchestratorUI",
            targets: ["MCPOrchestratorUI"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MCPOrchestratorUI",
            path: "MCPOrchestratorUI",
            sources: [
                "MCPOrchestratorUIApp.swift",
                "ModernContentView.swift",
                "DesignSystem.swift",
                "MCPCardView.swift",
                "ModernPreferencesView.swift",
                "ModernPerformanceDashboard.swift",
                "MCPServer.swift",
                "APIService.swift",
                "BackendManager.swift",
                "BackupManager.swift",
                "BackupRestoreView.swift",
                "ErrorDialogView.swift",
                "ErrorHandlingSystem.swift",
                "InstallServerView.swift",
                "LogViewerView.swift",
                "LoggingManager.swift",
                "PerformanceMonitor.swift",
                "PreferencesView.swift",
                "SettingsManager.swift",
                "SimpleLoggingManager.swift",
                "ServerConfigurationView.swift"
            ]
        )
    ]
) 