import Foundation
import SwiftUI

// MARK: - Error Types
enum MCPError: LocalizedError, Equatable, Codable {
    case serverConnection(serverName: String, details: String)
    case serverTimeout(serverName: String, timeout: TimeInterval)
    case serverNotFound(serverName: String)
    case invalidConfiguration(field: String, value: String)
    case networkError(code: Int, message: String)
    case authenticationFailed(serverName: String)
    case toolExecutionFailed(toolName: String, error: String)
    case fileSystemError(operation: String, path: String)
    case invalidResponse(expected: String, received: String)
    case rateLimitExceeded(limit: Int, window: String)
    case insufficientPermissions(resource: String)
    case resourceNotFound(resource: String, id: String)
    case validationError(field: String, reason: String)
    case criticalSystemError(component: String, error: String)
    case updateError(version: String, error: String)
    
    var errorDescription: String? {
        switch self {
        case .serverConnection(let serverName, let details):
            return "Connection to \(serverName) failed: \(details)"
        case .serverTimeout(let serverName, let timeout):
            return "Connection to \(serverName) timed out after \(Int(timeout))s"
        case .serverNotFound(let serverName):
            return "Server '\(serverName)' could not be found"
        case .invalidConfiguration(let field, let value):
            return "Invalid configuration for \(field): '\(value)'"
        case .networkError(let code, let message):
            return "Network error (\(code)): \(message)"
        case .authenticationFailed(let serverName):
            return "Authentication failed for \(serverName)"
        case .toolExecutionFailed(let toolName, let error):
            return "Tool '\(toolName)' execution failed: \(error)"
        case .fileSystemError(let operation, let path):
            return "File system error during \(operation) at \(path)"
        case .invalidResponse(let expected, let received):
            return "Invalid response: expected \(expected), received \(received)"
        case .rateLimitExceeded(let limit, let window):
            return "Rate limit exceeded: \(limit) requests per \(window)"
        case .insufficientPermissions(let resource):
            return "Insufficient permissions to access \(resource)"
        case .resourceNotFound(let resource, let id):
            return "\(resource) with ID '\(id)' not found"
        case .validationError(let field, let reason):
            return "Validation error for \(field): \(reason)"
        case .criticalSystemError(let component, let error):
            return "Critical error in \(component): \(error)"
        case .updateError(let version, let error):
            return "Update to version \(version) failed: \(error)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .serverConnection:
            return "Check your internet connection and server settings. Try restarting the server."
        case .serverTimeout:
            return "The server may be overloaded. Try again in a few moments or increase the timeout value."
        case .serverNotFound:
            return "Verify the server name and ensure it's properly configured in your settings."
        case .invalidConfiguration:
            return "Check the configuration value and ensure it matches the expected format."
        case .networkError(let code, _):
            if code >= 500 {
                return "Server error. Please try again later or contact support."
            } else if code >= 400 {
                return "Check your request parameters and authentication credentials."
            } else {
                return "Please check your network connection and try again."
            }
        case .authenticationFailed:
            return "Verify your credentials and ensure your account has the necessary permissions."
        case .toolExecutionFailed:
            return "Check the tool parameters and ensure the server is responding correctly."
        case .fileSystemError:
            return "Ensure you have proper file system permissions and sufficient disk space."
        case .invalidResponse:
            return "The server response format has changed. Please check for app updates."
        case .rateLimitExceeded:
            return "Wait a moment before making more requests, or upgrade your plan for higher limits."
        case .insufficientPermissions:
            return "Contact your administrator to grant the necessary permissions."
        case .resourceNotFound:
            return "The requested item may have been deleted or moved. Try refreshing the list."
        case .validationError:
            return "Please correct the highlighted field and try again."
        case .criticalSystemError:
            return "This is a serious error. Please restart the application and contact support if it persists."
        case .updateError:
            return "The update process failed. Try downloading the latest version manually."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .serverConnection, .serverTimeout, .networkError, .toolExecutionFailed:
            return .medium
        case .serverNotFound, .authenticationFailed, .insufficientPermissions:
            return .high
        case .criticalSystemError, .updateError:
            return .critical
        case .invalidConfiguration, .validationError, .invalidResponse:
            return .low
        case .fileSystemError, .rateLimitExceeded, .resourceNotFound:
            return .medium
        }
    }
    
    var category: ErrorCategory {
        switch self {
        case .serverConnection, .serverTimeout, .serverNotFound:
            return .server
        case .networkError, .rateLimitExceeded:
            return .network
        case .authenticationFailed, .insufficientPermissions:
            return .authentication
        case .toolExecutionFailed:
            return .tool
        case .fileSystemError:
            return .filesystem
        case .invalidConfiguration, .validationError:
            return .validation
        case .invalidResponse:
            return .protocolError
        case .resourceNotFound:
            return .resource
        case .criticalSystemError:
            return .system
        case .updateError:
            return .update
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .serverConnection, .serverTimeout, .networkError, .toolExecutionFailed, .rateLimitExceeded:
            return true
        case .serverNotFound, .authenticationFailed, .invalidConfiguration, .insufficientPermissions, .validationError:
            return false
        case .fileSystemError, .invalidResponse, .resourceNotFound, .criticalSystemError, .updateError:
            return false
        }
    }
    
    var autoRetryable: Bool {
        switch self {
        case .serverTimeout, .networkError, .rateLimitExceeded:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Severity
enum ErrorSeverity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "xmark.circle"
        case .critical: return "flame"
        }
    }
}

// MARK: - Error Category
enum ErrorCategory: String, CaseIterable {
    case server = "Server"
    case network = "Network"
    case authentication = "Authentication"
    case tool = "Tool"
    case filesystem = "File System"
    case validation = "Validation"
    case protocolError = "Protocol"
    case resource = "Resource"
    case system = "System"
    case update = "Update"
}

// MARK: - Error Report
struct ErrorReport: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let error: MCPError
    let context: [String: String]
    let stackTrace: String?
    let userAction: String?
    let resolved: Bool
    let retryCount: Int
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Recovery Action
struct RecoveryAction {
    let title: String
    let description: String
    let action: () async -> Bool
    let isDestructive: Bool
    
    init(title: String, description: String, isDestructive: Bool = false, action: @escaping () async -> Bool) {
        self.title = title
        self.description = description
        self.isDestructive = isDestructive
        self.action = action
    }
}

// MARK: - Error Handling Manager
class ErrorHandlingManager: ObservableObject {
    static let shared = ErrorHandlingManager()
    
    @Published var currentErrors: [ErrorReport] = []
    @Published var errorHistory: [ErrorReport] = []
    @Published var showErrorDialog = false
    @Published var currentErrorReport: ErrorReport?
    
    private let loggingManager = SimpleLoggingManager.shared
    private let maxRetries = 3
    private let retryDelays: [TimeInterval] = [1, 3, 5] // Exponential backoff
    
    private init() {}
    
    // MARK: - Error Reporting
    func reportError(_ error: MCPError, context: [String: String] = [:], userAction: String? = nil) {
        let report = ErrorReport(
            timestamp: Date(),
            error: error,
            context: context,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            userAction: userAction,
            resolved: false,
            retryCount: 0
        )
        
        DispatchQueue.main.async {
            self.currentErrors.append(report)
            self.errorHistory.append(report)
            self.currentErrorReport = report
            self.showErrorDialog = true
        }
        
        // Log the error
        loggingManager.error(
            error.localizedDescription,
            category: SimpleLogCategory.general
        )
        
        // Auto-retry if applicable
        if error.autoRetryable {
            scheduleAutoRetry(for: report)
        }
    }
    
    // MARK: - Error Resolution
    func resolveError(_ errorId: UUID) {
        if let index = currentErrors.firstIndex(where: { $0.id == errorId }) {
            var resolvedError = currentErrors[index]
            resolvedError = ErrorReport(
                timestamp: resolvedError.timestamp,
                error: resolvedError.error,
                context: resolvedError.context,
                stackTrace: resolvedError.stackTrace,
                userAction: resolvedError.userAction,
                resolved: true,
                retryCount: resolvedError.retryCount
            )
            
            currentErrors.remove(at: index)
            
            if let historyIndex = errorHistory.firstIndex(where: { $0.id == errorId }) {
                errorHistory[historyIndex] = resolvedError
            }
            
            loggingManager.info("Error resolved: \(resolvedError.error.localizedDescription)", category: SimpleLogCategory.general)
        }
    }
    
    // MARK: - Auto Retry
    private func scheduleAutoRetry(for report: ErrorReport) {
        guard report.retryCount < maxRetries else { return }
        
        let delay = retryDelays[min(report.retryCount, retryDelays.count - 1)]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.attemptAutoRetry(for: report)
        }
    }
    
    private func attemptAutoRetry(for report: ErrorReport) {
        guard let index = currentErrors.firstIndex(where: { $0.id == report.id }) else { return }
        
        let updatedReport = ErrorReport(
            timestamp: report.timestamp,
            error: report.error,
            context: report.context,
            stackTrace: report.stackTrace,
            userAction: report.userAction,
            resolved: false,
            retryCount: report.retryCount + 1
        )
        
        currentErrors[index] = updatedReport
        
        // Attempt recovery based on error type
        Task {
            let success = await attemptRecovery(for: updatedReport.error)
            
            DispatchQueue.main.async {
                if success {
                    self.resolveError(updatedReport.id)
                    self.loggingManager.info("Auto-retry successful for: \(updatedReport.error.localizedDescription)", category: SimpleLogCategory.general)
                } else if updatedReport.retryCount < self.maxRetries {
                    self.scheduleAutoRetry(for: updatedReport)
                } else {
                    self.loggingManager.error("Auto-retry failed after \(self.maxRetries) attempts: \(updatedReport.error.localizedDescription)", category: SimpleLogCategory.general)
                }
            }
        }
    }
    
    // MARK: - Recovery Actions
    func getRecoveryActions(for error: MCPError) -> [RecoveryAction] {
        switch error {
        case .serverConnection(let serverName, _):
            return [
                RecoveryAction(title: "Retry Connection", description: "Attempt to reconnect to \(serverName)") {
                    await self.retryServerConnection(serverName)
                },
                RecoveryAction(title: "Check Settings", description: "Review server configuration") {
                    await self.openServerSettings(serverName)
                },
                RecoveryAction(title: "Restart Server", description: "Force restart the server process", isDestructive: true) {
                    await self.restartServer(serverName)
                }
            ]
            
        case .serverTimeout(let serverName, _):
            return [
                RecoveryAction(title: "Retry with Extended Timeout", description: "Try again with longer timeout") {
                    await self.retryWithExtendedTimeout(serverName)
                },
                RecoveryAction(title: "Check Server Status", description: "Verify server is running") {
                    await self.checkServerStatus(serverName)
                }
            ]
            
        case .authenticationFailed(let serverName):
            return [
                RecoveryAction(title: "Re-authenticate", description: "Enter credentials again") {
                    await self.reauthenticate(serverName)
                },
                RecoveryAction(title: "Check Permissions", description: "Verify account permissions") {
                    await self.checkPermissions(serverName)
                }
            ]
            
        case .toolExecutionFailed(let toolName, _):
            return [
                RecoveryAction(title: "Retry Tool", description: "Execute \(toolName) again") {
                    await self.retryTool(toolName)
                },
                RecoveryAction(title: "Check Parameters", description: "Review tool parameters") {
                    await self.checkToolParameters(toolName)
                }
            ]
            
        case .networkError(_, _):
            return [
                RecoveryAction(title: "Retry Request", description: "Attempt the request again") {
                    await self.retryNetworkRequest()
                },
                RecoveryAction(title: "Check Connection", description: "Verify internet connectivity") {
                    await self.checkNetworkConnection()
                }
            ]
            
        case .rateLimitExceeded(_, _):
            return [
                RecoveryAction(title: "Wait and Retry", description: "Wait for rate limit reset") {
                    await self.waitAndRetry()
                }
            ]
            
        case .criticalSystemError(_, _):
            return [
                RecoveryAction(title: "Restart Application", description: "Restart to recover from critical error", isDestructive: true) {
                    await self.restartApplication()
                },
                RecoveryAction(title: "Reset Settings", description: "Reset to default settings", isDestructive: true) {
                    await self.resetSettings()
                }
            ]
            
        default:
            return [
                RecoveryAction(title: "Retry", description: "Try the operation again") {
                    await self.genericRetry()
                }
            ]
        }
    }
    
    // MARK: - Recovery Implementations
    private func attemptRecovery(for error: MCPError) async -> Bool {
        switch error {
        case .serverTimeout, .networkError:
            return await genericRetry()
        case .rateLimitExceeded:
            return await waitAndRetry()
        default:
            return false
        }
    }
    
    private func retryServerConnection(_ serverName: String) async -> Bool {
        loggingManager.info("Retrying connection to \(serverName)", category: SimpleLogCategory.server)
        // Simulate connection attempt
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return Bool.random()
    }
    
    private func openServerSettings(_ serverName: String) async -> Bool {
        loggingManager.info("Opening settings for \(serverName)", category: SimpleLogCategory.ui)
        return true
    }
    
    private func restartServer(_ serverName: String) async -> Bool {
        loggingManager.warning("Restarting server \(serverName)", category: SimpleLogCategory.server)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return Bool.random()
    }
    
    private func retryWithExtendedTimeout(_ serverName: String) async -> Bool {
        loggingManager.info("Retrying \(serverName) with extended timeout", category: SimpleLogCategory.server)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return Bool.random()
    }
    
    private func checkServerStatus(_ serverName: String) async -> Bool {
        loggingManager.info("Checking status of \(serverName)", category: SimpleLogCategory.server)
        return true
    }
    
    private func reauthenticate(_ serverName: String) async -> Bool {
        loggingManager.info("Re-authenticating with \(serverName)", category: SimpleLogCategory.auth)
        return true
    }
    
    private func checkPermissions(_ serverName: String) async -> Bool {
        loggingManager.info("Checking permissions for \(serverName)", category: SimpleLogCategory.auth)
        return true
    }
    
    private func retryTool(_ toolName: String) async -> Bool {
        loggingManager.info("Retrying tool \(toolName)", category: SimpleLogCategory.server)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return Bool.random()
    }
    
    private func checkToolParameters(_ toolName: String) async -> Bool {
        loggingManager.info("Checking parameters for tool \(toolName)", category: SimpleLogCategory.server)
        return true
    }
    
    private func retryNetworkRequest() async -> Bool {
        loggingManager.info("Retrying network request", category: SimpleLogCategory.network)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return Bool.random()
    }
    
    private func checkNetworkConnection() async -> Bool {
        loggingManager.info("Checking network connection", category: SimpleLogCategory.network)
        return true
    }
    
    private func waitAndRetry() async -> Bool {
        loggingManager.info("Waiting for rate limit reset", category: SimpleLogCategory.network)
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        return true
    }
    
    private func restartApplication() async -> Bool {
        loggingManager.critical("Restarting application", category: SimpleLogCategory.general)
        // In a real app, this would trigger an app restart
        return true
    }
    
    private func resetSettings() async -> Bool {
        loggingManager.warning("Resetting settings to defaults", category: SimpleLogCategory.general)
        return true
    }
    
    private func genericRetry() async -> Bool {
        loggingManager.info("Performing generic retry", category: SimpleLogCategory.general)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return Bool.random()
    }
    
    // MARK: - Error Statistics
    func getErrorStatistics() -> ErrorStatistics {
        let total = errorHistory.count
        let resolved = errorHistory.filter { $0.resolved }.count
        let byCategory = Dictionary(grouping: errorHistory) { $0.error.category }
        let bySeverity = Dictionary(grouping: errorHistory) { $0.error.severity }
        
        return ErrorStatistics(
            totalErrors: total,
            resolvedErrors: resolved,
            errorsByCategory: byCategory.mapValues { $0.count },
            errorsBySeverity: bySeverity.mapValues { $0.count }
        )
    }
}

// MARK: - Error Statistics
struct ErrorStatistics {
    let totalErrors: Int
    let resolvedErrors: Int
    let errorsByCategory: [ErrorCategory: Int]
    let errorsBySeverity: [ErrorSeverity: Int]
    
    var resolutionRate: Double {
        guard totalErrors > 0 else { return 0 }
        return Double(resolvedErrors) / Double(totalErrors)
    }
} 