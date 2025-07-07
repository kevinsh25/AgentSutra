import Foundation
import SwiftUI
import os.log

// MARK: - Simple Log Level
enum SimpleLogLevel: String, CaseIterable, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
    
    var color: Color {
        switch self {
        case .debug:
            return DesignSystem.Colors.textTertiary
        case .info:
            return DesignSystem.Colors.info
        case .warning:
            return DesignSystem.Colors.warning
        case .error:
            return DesignSystem.Colors.error
        case .critical:
            return DesignSystem.Colors.error
        }
    }
    
    var icon: String {
        switch self {
        case .debug:
            return "ant.circle"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
}

// MARK: - Simple Log Entry
struct SimpleLogEntry: Identifiable, Codable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: SimpleLogLevel
    let category: String
    let message: String
    let fileName: String
    let functionName: String
    let lineNumber: Int
    
    static func == (lhs: SimpleLogEntry, rhs: SimpleLogEntry) -> Bool {
        return lhs.id == rhs.id
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    var formattedMessage: String {
        return "[\(formattedTimestamp)] [\(level.rawValue)] [\(category)] \(message)"
    }
}

// MARK: - Simple Log Category
enum SimpleLogCategory: String, CaseIterable {
    case general = "GENERAL"
    case server = "SERVER"
    case api = "API"
    case ui = "UI"
    case health = "HEALTH"
    case performance = "PERFORMANCE"
    case security = "SECURITY"
    case network = "NETWORK"
    case plugin = "PLUGIN"
    case auth = "AUTH"
    case sync = "SYNC"
}

// MARK: - Simple Logging Manager
class SimpleLoggingManager: ObservableObject {
    static let shared = SimpleLoggingManager()
    
    @Published var logs: [SimpleLogEntry] = []
    @Published var isLoggingEnabled = true
    @Published var currentLogLevel: SimpleLogLevel = .info
    @Published var maxInMemoryLogs = 1000
    
    private let logQueue = DispatchQueue(label: "com.mcporchestrator.logging", qos: .background)
    private let fileManager = FileManager.default
    private let logger = os.Logger(subsystem: "com.mcporchestrator.MCPOrchestratorUI", category: "SimpleLoggingManager")
    
    private var logDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logDir = appSupport.appendingPathComponent("MCPOrchestrator/Logs")
        try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)
        return logDir
    }
    
    private var currentLogFile: URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "mcporchestrator-\(formatter.string(from: Date())).log"
        return logDirectory.appendingPathComponent(filename)
    }
    
    private init() {
        setupLogging()
        loadRecentLogs()
    }
    
    // MARK: - Setup
    private func setupLogging() {
        // Basic setup
        info("Logging system initialized", category: .general)
    }
    
    // MARK: - Public Logging Methods
    func debug(_ message: String, category: SimpleLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: SimpleLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: SimpleLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: SimpleLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: SimpleLogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    private func log(level: SimpleLogLevel, message: String, category: SimpleLogCategory, file: String, function: String, line: Int) {
        guard isLoggingEnabled && level.priority >= currentLogLevel.priority else { return }
        
        let entry = SimpleLogEntry(
            timestamp: Date(),
            level: level,
            category: category.rawValue,
            message: message,
            fileName: URL(fileURLWithPath: file).lastPathComponent,
            functionName: function,
            lineNumber: line
        )
        
        logQueue.async {
            self.processLogEntry(entry)
        }
    }
    
    private func processLogEntry(_ entry: SimpleLogEntry) {
        // Add to in-memory logs
        DispatchQueue.main.async {
            self.logs.append(entry)
            
            // Keep only max in-memory logs
            if self.logs.count > self.maxInMemoryLogs {
                self.logs.removeFirst(self.logs.count - self.maxInMemoryLogs)
            }
        }
        
        // Write to file
        writeToFile(entry)
        
        // Send to system logger
        sendToSystemLogger(entry)
    }
    
    private func writeToFile(_ entry: SimpleLogEntry) {
        let logLine = entry.formattedMessage + "\n"
        
        if let data = logLine.data(using: .utf8) {
            if fileManager.fileExists(atPath: currentLogFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: currentLogFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: currentLogFile)
            }
        }
    }
    
    private func sendToSystemLogger(_ entry: SimpleLogEntry) {
        switch entry.level {
        case .debug:
            logger.debug("\(entry.message, privacy: .public)")
        case .info:
            logger.info("\(entry.message, privacy: .public)")
        case .warning:
            logger.warning("\(entry.message, privacy: .public)")
        case .error:
            logger.error("\(entry.message, privacy: .public)")
        case .critical:
            logger.critical("\(entry.message, privacy: .public)")
        }
    }
    
    // MARK: - Log Management
    func clearLogs() {
        logs.removeAll()
        info("Logs cleared by user", category: .general)
    }
    
    func exportLogs() -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "mcporchestrator-logs-\(formatter.string(from: Date())).txt"
        
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(filename)
        
        let logText = logs.map { $0.formattedMessage }.joined(separator: "\n")
        
        guard let data = logText.data(using: .utf8) else { return nil }
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    func loadRecentLogs() {
        // Load from file if exists
        guard let data = try? Data(contentsOf: currentLogFile),
              let content = String(data: data, encoding: .utf8) else { return }
        
        let lines = content.components(separatedBy: .newlines)
        let recentLines = Array(lines.suffix(100)) // Load last 100 lines
        
        info("Loaded \(recentLines.count) recent log entries", category: .general)
    }
    
    // MARK: - Filtering
    func filteredLogs(level: SimpleLogLevel? = nil, category: SimpleLogCategory? = nil, searchText: String = "") -> [SimpleLogEntry] {
        var filtered = logs
        
        if let level = level {
            filtered = filtered.filter { $0.level.priority >= level.priority }
        }
        
        if let category = category {
            filtered = filtered.filter { $0.category == category.rawValue }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
}

// MARK: - Extensions for Date
extension Date {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 