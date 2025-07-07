import Foundation
import SwiftUI
import os.log

// MARK: - Performance Metrics
struct PerformanceMetrics: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let serverMetrics: [String: ServerPerformanceMetrics]
    let systemMetrics: SystemPerformanceMetrics
    let toolMetrics: [String: ToolPerformanceMetrics]
    let networkMetrics: NetworkPerformanceMetrics
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Server Performance Metrics
struct ServerPerformanceMetrics: Codable {
    let serverId: String
    let serverName: String
    let responseTime: TimeInterval // in milliseconds
    let successRate: Double // 0.0 to 1.0
    let requestCount: Int
    let errorCount: Int
    let memoryUsage: Double // in MB
    let cpuUsage: Double // percentage
    let uptime: TimeInterval // in seconds
    let lastRequestTime: Date?
    let averageRequestsPerMinute: Double
    let status: ServerStatus
    
    var healthScore: Double {
        let responseScore = max(0, min(100, (2000 - responseTime) / 20)) // Best at <100ms, worst at >2000ms
        let successScore = successRate * 100
        let uptimeScore = min(100, uptime / (24 * 60 * 60) * 100) // Best at 24h+ uptime
        
        return (responseScore + successScore + uptimeScore) / 3
    }
    
    var performanceLevel: PerformanceLevel {
        switch healthScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .critical
        }
    }
}

// MARK: - System Performance Metrics
struct SystemPerformanceMetrics: Codable {
    let memoryUsage: Double // percentage
    let memoryUsedMB: Double
    let memoryTotalMB: Double
    let cpuUsage: Double // percentage
    let diskUsage: Double // percentage
    let diskUsedGB: Double
    let diskTotalGB: Double
    let networkInKBps: Double
    let networkOutKBps: Double
    let activeConnections: Int
    let processCount: Int
    let threadCount: Int
    let appMemoryMB: Double
    
    var systemHealth: PerformanceLevel {
        let memoryScore = max(0, 100 - memoryUsage)
        let cpuScore = max(0, 100 - cpuUsage)
        let diskScore = max(0, 100 - diskUsage)
        
        let overallScore = (memoryScore + cpuScore + diskScore) / 3
        
        switch overallScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .critical
        }
    }
}

// MARK: - Tool Performance Metrics
struct ToolPerformanceMetrics: Codable {
    let toolName: String
    let serverId: String
    let executionCount: Int
    let successCount: Int
    let failureCount: Int
    let averageExecutionTime: TimeInterval
    let minExecutionTime: TimeInterval
    let maxExecutionTime: TimeInterval
    let lastExecutionTime: Date?
    let lastExecutionDuration: TimeInterval?
    let parametersUsed: [String: Int] // Parameter frequency
    
    var successRate: Double {
        guard executionCount > 0 else { return 0 }
        return Double(successCount) / Double(executionCount)
    }
    
    var efficiency: PerformanceLevel {
        let timeScore = max(0, min(100, (5000 - averageExecutionTime) / 50)) // Best at <1s, worst at >5s
        let successScore = successRate * 100
        
        let overallScore = (timeScore + successScore) / 2
        
        switch overallScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .critical
        }
    }
}

// MARK: - Network Performance Metrics
struct NetworkPerformanceMetrics: Codable {
    let totalRequests: Int
    let successfulRequests: Int
    let failedRequests: Int
    let averageLatency: TimeInterval
    let minLatency: TimeInterval
    let maxLatency: TimeInterval
    let bandwidth: Double // KB/s
    let packetsLost: Int
    let totalDataTransferred: Double // MB
    let connectionPoolSize: Int
    let activeConnections: Int
    
    var networkHealth: PerformanceLevel {
        let latencyScore = max(0, min(100, (1000 - averageLatency) / 10)) // Best at <100ms
        let successScore = totalRequests > 0 ? (Double(successfulRequests) / Double(totalRequests)) * 100 : 100
        let lossScore = totalRequests > 0 ? max(0, 100 - (Double(packetsLost) / Double(totalRequests)) * 100) : 100
        
        let overallScore = (latencyScore + successScore + lossScore) / 3
        
        switch overallScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .critical
        }
    }
}

// MARK: - Performance Level
enum PerformanceLevel: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "minus.circle"
        case .poor: return "exclamationmark.triangle"
        case .critical: return "xmark.circle.fill"
        }
    }
}

// MARK: - Server Status
enum ServerStatus: String, Codable {
    case online = "Online"
    case offline = "Offline"
    case degraded = "Degraded"
    case maintenance = "Maintenance"
    
    var color: Color {
        switch self {
        case .online: return .green
        case .offline: return .red
        case .degraded: return .orange
        case .maintenance: return .blue
        }
    }
}

// MARK: - Performance Alert
struct PerformanceAlert: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let type: AlertType
    let severity: AlertSeverity
    let title: String
    let message: String
    let source: String // server ID or system component
    let threshold: Double
    let currentValue: Double
    let acknowledged: Bool
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Alert Type
enum AlertType: String, CaseIterable, Codable {
    case highCpuUsage = "High CPU Usage"
    case highMemoryUsage = "High Memory Usage"
    case highDiskUsage = "High Disk Usage"
    case slowResponseTime = "Slow Response Time"
    case highErrorRate = "High Error Rate"
    case networkIssue = "Network Issue"
    case serverOffline = "Server Offline"
    case lowSuccessRate = "Low Success Rate"
}

// MARK: - Alert Severity
enum AlertSeverity: String, CaseIterable, Codable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "flame"
        }
    }
}

// MARK: - Performance Monitor
class PerformanceMonitor: ObservableObject {
    // MARK: - Initialization
    public static let shared = PerformanceMonitor()
    
    public init() {
        startMonitoring()
        loadStoredMetrics()
    }
    
    @Published var currentMetrics: PerformanceMetrics?
    @Published var metricsHistory: [PerformanceMetrics] = []
    @Published var activeAlerts: [PerformanceAlert] = []
    @Published var alertHistory: [PerformanceAlert] = []
    @Published var isMonitoring = true
    @Published var monitoringInterval: TimeInterval = 30 // seconds
    
    // Configuration
    @Published var alertThresholds = AlertThresholds()
    @Published var retentionDays = 7
    @Published var maxHistoryPoints = 1000
    
    private let loggingManager = SimpleLoggingManager.shared
    private var monitoringTimer: Timer?
    private let performanceQueue = DispatchQueue(label: "com.mcporchestrator.performance", qos: .utility)
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard isMonitoring else { return }
        
        stopMonitoring() // Stop any existing timer
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { _ in
            Task {
                await self.collectMetrics()
            }
        }
        
        loggingManager.info("Performance monitoring started with \(monitoringInterval)s interval", category: .performance)
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        loggingManager.info("Performance monitoring stopped", category: .performance)
    }
    
    func updateMonitoringInterval(_ interval: TimeInterval) {
        monitoringInterval = interval
        if isMonitoring {
            startMonitoring()
        }
    }
    
    // MARK: - Metrics Collection
    private func collectMetrics() async {
        performanceQueue.async {
            let metrics = PerformanceMetrics(
                timestamp: Date(),
                serverMetrics: self.collectServerMetrics(),
                systemMetrics: self.collectSystemMetrics(),
                toolMetrics: self.collectToolMetrics(),
                networkMetrics: self.collectNetworkMetrics()
            )
            
            DispatchQueue.main.async {
                self.currentMetrics = metrics
                self.metricsHistory.append(metrics)
                
                // Limit history size
                if self.metricsHistory.count > self.maxHistoryPoints {
                    self.metricsHistory.removeFirst(self.metricsHistory.count - self.maxHistoryPoints)
                }
                
                // Check for alerts
                self.checkForAlerts(metrics)
                
                // Clean up old data
                self.cleanupOldData()
            }
        }
    }
    
    private func collectServerMetrics() -> [String: ServerPerformanceMetrics] {
        // In a real implementation, this would collect actual server metrics
        let servers = ["github-server", "slack-server", "notion-server"]
        var serverMetrics: [String: ServerPerformanceMetrics] = [:]
        
        for serverId in servers {
            let baseResponseTime = Double.random(in: 100...800)
            let jitter = Double.random(in: -50...50)
            
            serverMetrics[serverId] = ServerPerformanceMetrics(
                serverId: serverId,
                serverName: serverId.replacingOccurrences(of: "-server", with: "").capitalized,
                responseTime: max(10, baseResponseTime + jitter),
                successRate: Double.random(in: 0.85...0.99),
                requestCount: Int.random(in: 50...200),
                errorCount: Int.random(in: 0...10),
                memoryUsage: Double.random(in: 20...80),
                cpuUsage: Double.random(in: 5...25),
                uptime: TimeInterval.random(in: 3600...86400*7),
                lastRequestTime: Date().addingTimeInterval(-Double.random(in: 0...300)),
                averageRequestsPerMinute: Double.random(in: 5...30),
                status: Bool.random() ? .online : (Bool.random() ? .degraded : .offline)
            )
        }
        
        return serverMetrics
    }
    
    private func collectSystemMetrics() -> SystemPerformanceMetrics {
        // Simulate system metrics collection
        return SystemPerformanceMetrics(
            memoryUsage: Double.random(in: 30...85),
            memoryUsedMB: Double.random(in: 2000...6000),
            memoryTotalMB: 8192,
            cpuUsage: Double.random(in: 10...60),
            diskUsage: Double.random(in: 40...75),
            diskUsedGB: Double.random(in: 200...400),
            diskTotalGB: 512,
            networkInKBps: Double.random(in: 50...500),
            networkOutKBps: Double.random(in: 20...200),
            activeConnections: Int.random(in: 5...25),
            processCount: Int.random(in: 200...350),
            threadCount: Int.random(in: 1000...2000),
            appMemoryMB: Double.random(in: 150...400)
        )
    }
    
    private func collectToolMetrics() -> [String: ToolPerformanceMetrics] {
        let tools = ["github-list-repos", "slack-send-message", "notion-create-page", "github-create-issue"]
        var toolMetrics: [String: ToolPerformanceMetrics] = [:]
        
        for tool in tools {
            let execCount = Int.random(in: 20...100)
            let successCount = Int.random(in: execCount-10...execCount)
            
            toolMetrics[tool] = ToolPerformanceMetrics(
                toolName: tool,
                serverId: tool.components(separatedBy: "-").first ?? "unknown",
                executionCount: execCount,
                successCount: successCount,
                failureCount: execCount - successCount,
                averageExecutionTime: Double.random(in: 500...3000),
                minExecutionTime: Double.random(in: 200...500),
                maxExecutionTime: Double.random(in: 3000...8000),
                lastExecutionTime: Date().addingTimeInterval(-Double.random(in: 0...3600)),
                lastExecutionDuration: Double.random(in: 400...2000),
                parametersUsed: [
                    "param1": Int.random(in: 5...50),
                    "param2": Int.random(in: 2...20),
                    "param3": Int.random(in: 1...10)
                ]
            )
        }
        
        return toolMetrics
    }
    
    private func collectNetworkMetrics() -> NetworkPerformanceMetrics {
        let totalReq = Int.random(in: 100...500)
        let successReq = Int.random(in: totalReq-20...totalReq)
        
        return NetworkPerformanceMetrics(
            totalRequests: totalReq,
            successfulRequests: successReq,
            failedRequests: totalReq - successReq,
            averageLatency: Double.random(in: 50...300),
            minLatency: Double.random(in: 20...50),
            maxLatency: Double.random(in: 300...1000),
            bandwidth: Double.random(in: 1000...5000),
            packetsLost: Int.random(in: 0...5),
            totalDataTransferred: Double.random(in: 50...200),
            connectionPoolSize: Int.random(in: 10...50),
            activeConnections: Int.random(in: 5...25)
        )
    }
    
    // MARK: - Alert Management
    private func checkForAlerts(_ metrics: PerformanceMetrics) {
        // Check system alerts
        checkSystemAlerts(metrics.systemMetrics)
        
        // Check server alerts
        for (_, serverMetrics) in metrics.serverMetrics {
            checkServerAlerts(serverMetrics)
        }
        
        // Check network alerts
        checkNetworkAlerts(metrics.networkMetrics)
    }
    
    private func checkSystemAlerts(_ metrics: SystemPerformanceMetrics) {
        // CPU usage alert
        if metrics.cpuUsage > alertThresholds.maxCpuUsage {
            createAlert(
                type: .highCpuUsage,
                severity: metrics.cpuUsage > alertThresholds.criticalCpuUsage ? .critical : .warning,
                title: "High CPU Usage",
                message: "CPU usage is at \(String(format: "%.1f", metrics.cpuUsage))%",
                source: "system",
                threshold: alertThresholds.maxCpuUsage,
                currentValue: metrics.cpuUsage
            )
        }
        
        // Memory usage alert
        if metrics.memoryUsage > alertThresholds.maxMemoryUsage {
            createAlert(
                type: .highMemoryUsage,
                severity: metrics.memoryUsage > alertThresholds.criticalMemoryUsage ? .critical : .warning,
                title: "High Memory Usage",
                message: "Memory usage is at \(String(format: "%.1f", metrics.memoryUsage))%",
                source: "system",
                threshold: alertThresholds.maxMemoryUsage,
                currentValue: metrics.memoryUsage
            )
        }
        
        // Disk usage alert
        if metrics.diskUsage > alertThresholds.maxDiskUsage {
            createAlert(
                type: .highDiskUsage,
                severity: metrics.diskUsage > alertThresholds.criticalDiskUsage ? .critical : .warning,
                title: "High Disk Usage",
                message: "Disk usage is at \(String(format: "%.1f", metrics.diskUsage))%",
                source: "system",
                threshold: alertThresholds.maxDiskUsage,
                currentValue: metrics.diskUsage
            )
        }
    }
    
    private func checkServerAlerts(_ metrics: ServerPerformanceMetrics) {
        // Response time alert
        if metrics.responseTime > alertThresholds.maxResponseTime {
            createAlert(
                type: .slowResponseTime,
                severity: metrics.responseTime > alertThresholds.criticalResponseTime ? .critical : .warning,
                title: "Slow Response Time",
                message: "\(metrics.serverName) response time is \(String(format: "%.0f", metrics.responseTime))ms",
                source: metrics.serverId,
                threshold: alertThresholds.maxResponseTime,
                currentValue: metrics.responseTime
            )
        }
        
        // Error rate alert
        let errorRate = Double(metrics.errorCount) / Double(max(1, metrics.requestCount))
        if errorRate > alertThresholds.maxErrorRate {
            createAlert(
                type: .highErrorRate,
                severity: errorRate > alertThresholds.criticalErrorRate ? .critical : .warning,
                title: "High Error Rate",
                message: "\(metrics.serverName) error rate is \(String(format: "%.1f", errorRate * 100))%",
                source: metrics.serverId,
                threshold: alertThresholds.maxErrorRate,
                currentValue: errorRate
            )
        }
        
        // Server offline alert
        if metrics.status == .offline {
            createAlert(
                type: .serverOffline,
                severity: .critical,
                title: "Server Offline",
                message: "\(metrics.serverName) is offline",
                source: metrics.serverId,
                threshold: 0,
                currentValue: 0
            )
        }
    }
    
    private func checkNetworkAlerts(_ metrics: NetworkPerformanceMetrics) {
        // Network latency alert
        if metrics.averageLatency > alertThresholds.maxNetworkLatency {
            createAlert(
                type: .networkIssue,
                severity: metrics.averageLatency > alertThresholds.criticalNetworkLatency ? .critical : .warning,
                title: "High Network Latency",
                message: "Average latency is \(String(format: "%.0f", metrics.averageLatency))ms",
                source: "network",
                threshold: alertThresholds.maxNetworkLatency,
                currentValue: metrics.averageLatency
            )
        }
    }
    
    private func createAlert(type: AlertType, severity: AlertSeverity, title: String, message: String, source: String, threshold: Double, currentValue: Double) {
        // Check if similar alert already exists
        let existingSimilar = activeAlerts.first { alert in
            alert.type == type && alert.source == source && !alert.acknowledged
        }
        
        guard existingSimilar == nil else { return }
        
        let alert = PerformanceAlert(
            timestamp: Date(),
            type: type,
            severity: severity,
            title: title,
            message: message,
            source: source,
            threshold: threshold,
            currentValue: currentValue,
            acknowledged: false
        )
        
        activeAlerts.append(alert)
        alertHistory.append(alert)
        
        loggingManager.warning("Performance alert: \(title) - \(message)", category: .performance)
    }
    
    func acknowledgeAlert(_ alertId: UUID) {
        if let index = activeAlerts.firstIndex(where: { $0.id == alertId }) {
            let alert = activeAlerts[index]
            let acknowledgedAlert = PerformanceAlert(
                timestamp: alert.timestamp,
                type: alert.type,
                severity: alert.severity,
                title: alert.title,
                message: alert.message,
                source: alert.source,
                threshold: alert.threshold,
                currentValue: alert.currentValue,
                acknowledged: true
            )
            
            activeAlerts.remove(at: index)
            
            if let historyIndex = alertHistory.firstIndex(where: { $0.id == alertId }) {
                alertHistory[historyIndex] = acknowledgedAlert
            }
            
            loggingManager.info("Performance alert acknowledged: \(alert.title)", category: .performance)
        }
    }
    
    // MARK: - Data Management
    private func cleanupOldData() {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(retentionDays * 24 * 60 * 60))
        
        metricsHistory.removeAll { $0.timestamp < cutoffDate }
        alertHistory.removeAll { $0.timestamp < cutoffDate }
    }
    
    private func loadStoredMetrics() {
        // In a real implementation, load from persistent storage
        loggingManager.info("Performance metrics loaded from storage", category: .performance)
    }
    
    // MARK: - Analytics
    func getPerformanceSummary() -> PerformanceSummary {
        guard !metricsHistory.isEmpty else {
            return PerformanceSummary.empty
        }
        
        let recentMetrics = Array(metricsHistory.suffix(100)) // Last 100 data points
        
        let avgSystemCpu = recentMetrics.map { $0.systemMetrics.cpuUsage }.reduce(0, +) / Double(recentMetrics.count)
        let avgSystemMemory = recentMetrics.map { $0.systemMetrics.memoryUsage }.reduce(0, +) / Double(recentMetrics.count)
        
        let totalRequests = recentMetrics.map { $0.networkMetrics.totalRequests }.reduce(0, +)
        let totalSuccessful = recentMetrics.map { $0.networkMetrics.successfulRequests }.reduce(0, +)
        let successRate = totalRequests > 0 ? Double(totalSuccessful) / Double(totalRequests) : 0
        
        let totalAlerts = alertHistory.count
        let criticalAlerts = alertHistory.filter { $0.severity == .critical }.count
        
        return PerformanceSummary(
            averageSystemCpuUsage: avgSystemCpu,
            averageSystemMemoryUsage: avgSystemMemory,
            totalRequests: totalRequests,
            overallSuccessRate: successRate,
            totalAlerts: totalAlerts,
            criticalAlerts: criticalAlerts,
            monitoringUptime: Date().timeIntervalSince(metricsHistory.first?.timestamp ?? Date()),
            dataPoints: recentMetrics.count
        )
    }
}

// MARK: - Alert Thresholds
struct AlertThresholds: Codable {
    var maxCpuUsage: Double = 80.0
    var criticalCpuUsage: Double = 95.0
    var maxMemoryUsage: Double = 85.0
    var criticalMemoryUsage: Double = 95.0
    var maxDiskUsage: Double = 90.0
    var criticalDiskUsage: Double = 98.0
    var maxResponseTime: Double = 2000.0 // ms
    var criticalResponseTime: Double = 5000.0 // ms
    var maxErrorRate: Double = 0.05 // 5%
    var criticalErrorRate: Double = 0.15 // 15%
    var maxNetworkLatency: Double = 500.0 // ms
    var criticalNetworkLatency: Double = 1000.0 // ms
}

// MARK: - Performance Summary
struct PerformanceSummary {
    let averageSystemCpuUsage: Double
    let averageSystemMemoryUsage: Double
    let totalRequests: Int
    let overallSuccessRate: Double
    let totalAlerts: Int
    let criticalAlerts: Int
    let monitoringUptime: TimeInterval
    let dataPoints: Int
    
    static let empty = PerformanceSummary(
        averageSystemCpuUsage: 0,
        averageSystemMemoryUsage: 0,
        totalRequests: 0,
        overallSuccessRate: 0,
        totalAlerts: 0,
        criticalAlerts: 0,
        monitoringUptime: 0,
        dataPoints: 0
    )
    
    var systemHealthLevel: PerformanceLevel {
        let cpuScore = max(0, 100 - averageSystemCpuUsage)
        let memoryScore = max(0, 100 - averageSystemMemoryUsage)
        let successScore = overallSuccessRate * 100
        
        let overallScore = (cpuScore + memoryScore + successScore) / 3
        
        switch overallScore {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        case 20..<40: return .poor
        default: return .critical
        }
    }
} 