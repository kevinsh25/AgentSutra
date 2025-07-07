import Foundation
import SwiftUI
import os.log

// MARK: - Log Level
enum LogLevel: String, CaseIterable, Codable {
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
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "flame"
        }
    }
    
    var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Log Entry
struct LogEntry: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let metadata: [String: String]
    let threadId: String
    let fileName: String
    let functionName: String
    let lineNumber: Int
    
    init(timestamp: Date, level: LogLevel, category: String, message: String, metadata: [String: String] = [:], threadId: String = "", fileName: String = "", functionName: String = "", lineNumber: Int = 0) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.threadId = threadId
        self.fileName = fileName
        self.functionName = functionName
        self.lineNumber = lineNumber
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var formattedMessage: String {
        return "[\(formattedTimestamp)] [\(level.rawValue)] [\(category)] \(message)"
    }
}

// MARK: - Log Category
enum LogCategory: String, CaseIterable {
    case general = "GENERAL"
    case server = "SERVER"
    case api = "API"
    case ui = "UI"
    case health = "HEALTH"
    case performance = "PERFORMANCE"
    case security = "SECURITY"
    case network = "NETWORK"
    case database = "DATABASE"
    case plugin = "PLUGIN"
    case auth = "AUTH"
    case sync = "SYNC"
}

// MARK: - Logging Manager
class LoggingManager: ObservableObject {
    static let shared = LoggingManager()
    
    @Published var logs: [LogEntry] = []
    @Published var isLoggingEnabled = true
    @Published var currentLogLevel: LogLevel = .info
    @Published var maxInMemoryLogs = 1000
    
    // Logging settings (will be integrated with SettingsManager later)
    private var logLevel: String = "INFO"
    private var writeToFile: Bool = true
    private var logRetentionDays: Int = 30
    private var maxLogSize: Int = 10 // MB
    private var maxInMemoryLogsLimit: Int = 1000
    private var enabled: Bool = true
    
    private let logQueue = DispatchQueue(label: "com.mcporchestrator.logging", qos: .background)
    private let fileManager = FileManager.default
    private let logger = os.Logger(subsystem: "com.mcporchestrator.MCPOrchestratorUI", category: "LoggingManager")
    
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
        currentLogLevel = LogLevel(rawValue: logLevel) ?? .info
        isLoggingEnabled = enabled
        maxInMemoryLogs = maxInMemoryLogsLimit
        
        // Start log rotation timer
        startLogRotationTimer()
    }
    
    private func startLogRotationTimer() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.rotateLogsIfNeeded()
        }
    }
    
    // MARK: - Public Logging Methods
    func debug(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    private func log(level: LogLevel, message: String, category: LogCategory, metadata: [String: String], file: String, function: String, line: Int) {
        guard isLoggingEnabled && level.priority >= currentLogLevel.priority else { return }
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category.rawValue,
            message: message,
            metadata: metadata,
            threadId: Thread.current.description,
            fileName: URL(fileURLWithPath: file).lastPathComponent,
            functionName: function,
            lineNumber: line
        )
        
        logQueue.async {
            self.processLogEntry(entry)
        }
    }
    
    private func processLogEntry(_ entry: LogEntry) {
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
    
    private func writeToFile(_ entry: LogEntry) {
        guard writeToFile else { return }
        
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
    
    private func sendToSystemLogger(_ entry: LogEntry) {
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
        logQueue.async {
            self.loadLogsFromFile()
        }
    }
    
    private func loadLogsFromFile() {
        guard let data = try? Data(contentsOf: currentLogFile),
              let content = String(data: data, encoding: .utf8) else { return }
        
        let lines = content.components(separatedBy: .newlines)
        let recentLines = Array(lines.suffix(500)) // Load last 500 lines
        
        // Parse log lines back to LogEntry objects (simplified version)
        var parsedLogs: [LogEntry] = []
        for line in recentLines {
            if let entry = parseLogLine(line) {
                parsedLogs.append(entry)
            }
        }
        
        DispatchQueue.main.async {
            self.logs = parsedLogs
        }
    }
    
    private func parseLogLine(_ line: String) -> LogEntry? {
        // Simplified parsing - in production, use proper regex
        let components = line.components(separatedBy: "] [")
        guard components.count >= 4 else { return nil }
        
        let timestampStr = components[0].replacingOccurrences(of: "[", with: "")
        let levelStr = components[1]
        let categoryStr = components[2]
        let messageStr = components[3].replacingOccurrences(of: "]", with: "")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        return LogEntry(
            timestamp: formatter.date(from: timestampStr) ?? Date(),
            level: LogLevel(rawValue: levelStr) ?? .info,
            category: categoryStr,
            message: messageStr,
            metadata: [:],
            threadId: "",
            fileName: "",
            functionName: "",
            lineNumber: 0
        )
    }
    
    // MARK: - Log Rotation
    private func rotateLogsIfNeeded() {
        let files = try? fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        // Remove old log files
        let maxAge = TimeInterval(logRetentionDays * 24 * 60 * 60)
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        files?.forEach { file in
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < cutoffDate {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // Check current log file size
        if let attributes = try? fileManager.attributesOfItem(atPath: currentLogFile.path),
           let size = attributes[.size] as? Int64 {
            let maxSize = Int64(maxLogSize * 1024 * 1024) // Convert MB to bytes
            
            if size > maxSize {
                archiveCurrentLogFile()
            }
        }
    }
    
    private func archiveCurrentLogFile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let archiveName = "mcporchestrator-\(timestamp).log"
        let archiveURL = logDirectory.appendingPathComponent(archiveName)
        
        try? fileManager.moveItem(at: currentLogFile, to: archiveURL)
        
        info("Log file archived: \(archiveName)", category: .general)
    }
    
    // MARK: - Filtering
    func filteredLogs(level: LogLevel? = nil, category: LogCategory? = nil, searchText: String = "") -> [LogEntry] {
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
    
    // MARK: - Settings Integration
    func updateSettings() {
        setupLogging()
        info("Logging settings updated", category: .general)
    }
} 