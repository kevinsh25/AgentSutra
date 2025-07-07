import SwiftUI
import UniformTypeIdentifiers

struct LogViewerView: View {
    @StateObject private var loggingManager = SimpleLoggingManager.shared
    @State private var selectedLevel: SimpleLogLevel? = nil
    @State private var selectedCategory: SimpleLogCategory? = nil
    @State private var searchText = ""
    @State private var showExportDialog = false
    @State private var exportURL: URL? = nil
    @State private var autoScroll = true
    @State private var showingLogDetail = false
    @State private var selectedLogEntry: SimpleLogEntry? = nil
    
    var filteredLogs: [SimpleLogEntry] {
        return loggingManager.filteredLogs(level: selectedLevel, category: selectedCategory, searchText: searchText)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with controls
                VStack(spacing: 12) {
                    HStack {
                        Text("System Logs")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Real-time indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(loggingManager.isLoggingEnabled ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(loggingManager.isLoggingEnabled ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(), value: loggingManager.isLoggingEnabled)
                            
                            Text(loggingManager.isLoggingEnabled ? "Live" : "Stopped")
                                .font(.caption)
                                .foregroundColor(loggingManager.isLoggingEnabled ? .green : .red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Stats overview
                    HStack(spacing: 20) {
                        StatCard(title: "Total Logs", value: "\(loggingManager.logs.count)", color: .blue)
                        StatCard(title: "Errors", value: "\(loggingManager.logs.filter { $0.level.priority >= SimpleLogLevel.error.priority }.count)", color: .red)
                        StatCard(title: "Warnings", value: "\(loggingManager.logs.filter { $0.level == .warning }.count)", color: .orange)
                        StatCard(title: "Info", value: "\(loggingManager.logs.filter { $0.level == .info }.count)", color: .blue)
                    }
                    
                    // Filter controls
                    HStack(spacing: 12) {
                        // Search
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search logs...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .frame(maxWidth: 200)
                        
                        // Level filter
                        Menu {
                            Button("All Levels") {
                                selectedLevel = nil
                            }
                            Divider()
                            ForEach(SimpleLogLevel.allCases, id: \.self) { level in
                                Button(action: {
                                    selectedLevel = level
                                }) {
                                    HStack {
                                        Image(systemName: level.icon)
                                        Text(level.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedLevel?.icon ?? "line.horizontal.3.decrease.circle")
                                Text(selectedLevel?.rawValue ?? "All Levels")
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Category filter
                        Menu {
                            Button("All Categories") {
                                selectedCategory = nil
                            }
                            Divider()
                            ForEach(SimpleLogCategory.allCases, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    Text(category.rawValue)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text(selectedCategory?.rawValue ?? "All Categories")
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        // Controls
                        HStack(spacing: 8) {
                            Button(action: {
                                autoScroll.toggle()
                            }) {
                                Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                                    .foregroundColor(autoScroll ? .blue : .gray)
                            }
                            .help("Auto-scroll to newest logs")
                            
                            Button(action: {
                                loggingManager.clearLogs()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .help("Clear all logs")
                            
                            Button(action: {
                                exportLogs()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                            .help("Export logs")
                        }
                        .font(.title2)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Log content
                if filteredLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No logs found")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Try adjusting your filters or check back later")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        List(filteredLogs) { entry in
                            LogEntryRow(entry: entry) {
                                selectedLogEntry = entry
                                showingLogDetail = true
                            }
                            .id(entry.id)
                        }
                        .listStyle(PlainListStyle())
                        .onChange(of: filteredLogs) { _ in
                            if autoScroll && !filteredLogs.isEmpty {
                                withAnimation {
                                    proxy.scrollTo(filteredLogs.last?.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Logs")
        .sheet(isPresented: $showingLogDetail) {
            if let entry = selectedLogEntry {
                LogDetailView(entry: entry)
            }
        }
        .fileExporter(
            isPresented: $showExportDialog,
            document: exportURL != nil ? LogDocument(url: exportURL!) : nil,
            contentType: .plainText,
            defaultFilename: "mcporchestrator-logs"
        ) { result in
            switch result {
            case .success(let url):
                print("Logs exported to: \(url)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func exportLogs() {
        if let url = loggingManager.exportLogs() {
            exportURL = url
            showExportDialog = true
        }
    }
}

// MARK: - Log Entry Row
struct LogEntryRow: View {
    let entry: SimpleLogEntry
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Level indicator
            Rectangle()
                .fill(entry.level.color)
                .frame(width: 4)
            
            // Icon
            Image(systemName: entry.level.icon)
                .foregroundColor(entry.level.color)
                .font(.caption)
                .frame(width: 16)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(entry.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(entry.message)
                    .font(.body)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.message, forType: .string)
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Log Detail View
struct LogDetailView: View {
    let entry: SimpleLogEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: entry.level.icon)
                        .foregroundColor(entry.level.color)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text(entry.level.rawValue)
                            .font(.headline)
                            .foregroundColor(entry.level.color)
                        
                        Text(entry.formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(entry.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                // Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.headline)
                    
                    Text(entry.message)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                }
                
                // Source information
                if !entry.fileName.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("File:")
                                    .fontWeight(.medium)
                                Text(entry.fileName)
                            }
                            
                            HStack {
                                Text("Function:")
                                    .fontWeight(.medium)
                                Text(entry.functionName)
                            }
                            
                            HStack {
                                Text("Line:")
                                    .fontWeight(.medium)
                                Text("\(entry.lineNumber)")
                            }
                        }
                        .font(.caption)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Actions
                HStack {
                    Button("Copy Message") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.message, forType: .string)
                    }
                    
                    Button("Copy All Details") {
                        let details = """
                        Level: \(entry.level.rawValue)
                        Category: \(entry.category)
                        Time: \(entry.formattedTimestamp)
                        Message: \(entry.message)
                        File: \(entry.fileName)
                        Function: \(entry.functionName)
                        Line: \(entry.lineNumber)
                        """
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(details, forType: .string)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Log Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Log Document for Export
struct LogDocument: FileDocument {
    static var readableContentTypes = [UTType.plainText]
    
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.log")
        try data.write(to: tempURL)
        self.url = tempURL
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview
struct LogViewerView_Previews: PreviewProvider {
    static var previews: some View {
        LogViewerView()
            .frame(width: 800, height: 600)
    }
}

 