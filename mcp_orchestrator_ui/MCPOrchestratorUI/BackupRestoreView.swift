import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @StateObject private var backupManager = BackupManager.shared
    @State private var showingCreateBackup = false
    @State private var showingRestoreDialog = false
    @State private var showingImportDialog = false
    @State private var selectedBackup: BackupConfiguration?
    @State private var showingBackupDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Text("Backup & Restore")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Status indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(backupManager.autoBackupEnabled ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            
                            Text(backupManager.autoBackupEnabled ? "Auto-backup ON" : "Auto-backup OFF")
                                .font(.caption)
                                .foregroundColor(backupManager.autoBackupEnabled ? .green : .gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Stats overview
                    HStack(spacing: 20) {
                        BackupStatCard(
                            title: "Total Backups",
                            value: "\(backupManager.availableBackups.count)",
                            icon: "doc.on.doc",
                            color: .blue
                        )
                        
                        BackupStatCard(
                            title: "Last Backup",
                            value: backupManager.lastBackupDate?.timeAgo ?? "Never",
                            icon: "clock",
                            color: .green
                        )
                        
                        BackupStatCard(
                            title: "Total Size",
                            value: calculateTotalSize(),
                            icon: "internaldrive",
                            color: .orange
                        )
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            showingCreateBackup = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Create Backup")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(backupManager.isCreatingBackup)
                        
                        Button(action: {
                            showingImportDialog = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import")
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        if backupManager.isCreatingBackup {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Creating backup...")
                                    .font(.caption)
                            }
                        } else if backupManager.isRestoringBackup {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Restoring...")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Backup list
                if backupManager.availableBackups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No backups available")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Create your first backup to protect your configuration")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button("Create Backup") {
                            showingCreateBackup = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(backupManager.availableBackups, id: \.id) { backup in
                                BackupRowView(backup: backup) { action in
                                    handleBackupAction(action, for: backup)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateBackup) {
            CreateBackupView()
        }
        .sheet(isPresented: $showingRestoreDialog) {
            if let backup = selectedBackup {
                RestoreBackupView(backup: backup)
            }
        }
        .sheet(isPresented: $showingBackupDetail) {
            if let backup = selectedBackup {
                BackupDetailView(backup: backup)
            }
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [UTType(filenameExtension: "mcpbackup") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }
    
    private func calculateTotalSize() -> String {
        // Calculate total size of all backups
        let totalSizeString = backupManager.availableBackups
            .map { $0.size }
            .reduce("0 bytes") { _, size in size }
        
        return totalSizeString
    }
    
    private func handleBackupAction(_ action: BackupAction, for backup: BackupConfiguration) {
        switch action {
        case .restore:
            selectedBackup = backup
            showingRestoreDialog = true
        case .export:
            exportBackup(backup)
        case .delete:
            deleteBackup(backup)
        case .viewDetails:
            selectedBackup = backup
            showingBackupDetail = true
        }
    }
    
    private func exportBackup(_ backup: BackupConfiguration) {
        if let url = backupManager.exportBackup(backup) {
            // Show save dialog
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType(filenameExtension: "mcpbackup") ?? .data]
            savePanel.nameFieldStringValue = "\(backup.name).mcpbackup"
            
            savePanel.begin { response in
                if response == .OK, let destination = savePanel.url {
                    do {
                        try FileManager.default.copyItem(at: url, to: destination)
                    } catch {
                        // Handle error
                    }
                }
            }
        }
    }
    
    private func deleteBackup(_ backup: BackupConfiguration) {
        backupManager.deleteBackup(backup)
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                let result = await backupManager.importBackup(from: url)
                switch result {
                case .success:
                    // Success handled in BackupManager
                    break
                case .failure(let error):
                    // Show error dialog
                    break
                }
            }
            
        case .failure(let error):
            // Handle error
            break
        }
    }
}

// MARK: - Backup Action
enum BackupAction {
    case restore
    case export
    case delete
    case viewDetails
}

// MARK: - Backup Stat Card
struct BackupStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Backup Row View
struct BackupRowView: View {
    let backup: BackupConfiguration
    let onAction: (BackupAction) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(backup.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(backup.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(backup.size)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Details
            HStack(spacing: 16) {
                BackupFeatureIndicator(
                    icon: "gear",
                    label: "Settings",
                    enabled: backup.settings.includeSettings
                )
                
                BackupFeatureIndicator(
                    icon: "server.rack",
                    label: "Servers",
                    enabled: backup.settings.includeServerConfigs
                )
                
                BackupFeatureIndicator(
                    icon: "cpu",
                    label: "State",
                    enabled: backup.settings.includeOrchestratorState
                )
                
                BackupFeatureIndicator(
                    icon: "lock",
                    label: "Encrypted",
                    enabled: backup.settings.encryptionEnabled
                )
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button(action: {
                        onAction(.viewDetails)
                    }) {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("View details")
                    
                    Button(action: {
                        onAction(.export)
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Export backup")
                    
                    Button(action: {
                        onAction(.restore)
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Restore backup")
                    
                    Button(action: {
                        onAction(.delete)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete backup")
                }
                .font(.title3)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Backup Feature Indicator
struct BackupFeatureIndicator: View {
    let icon: String
    let label: String
    let enabled: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(enabled ? .green : .gray)
                .font(.caption)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(enabled ? .primary : .secondary)
        }
        .opacity(enabled ? 1.0 : 0.6)
    }
}

// MARK: - Create Backup View
struct CreateBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var backupManager = BackupManager.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var includeSettings = true
    @State private var includeServerConfigs = true
    @State private var includeOrchestratorState = true
    @State private var includeSecrets = false
    @State private var compressionEnabled = true
    @State private var encryptionEnabled = false
    @State private var isCreating = false
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Basic Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Backup Information")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter backup name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Optional description", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                }
                
                // Backup Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("What to Include")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Application Settings", isOn: $includeSettings)
                        Toggle("Server Configurations", isOn: $includeServerConfigs)
                        Toggle("Orchestrator State", isOn: $includeOrchestratorState)
                        Toggle("Encrypted Credentials", isOn: $includeSecrets)
                    }
                }
                
                // Advanced Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Advanced Options")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Compression", isOn: $compressionEnabled)
                        Toggle("Enable Encryption", isOn: $encryptionEnabled)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Create Backup") {
                        createBackup()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || isCreating)
                }
            }
            .padding()
            .navigationTitle("Create Backup")
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    Color.black.opacity(0.3)
                        .overlay {
                            VStack {
                                ProgressView()
                                Text("Creating backup...")
                                    .padding(.top, 8)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }
    
    private func createBackup() {
        isCreating = true
        
        let settings = BackupSettings(
            includeSettings: includeSettings,
            includeServerConfigs: includeServerConfigs,
            includeOrchestratorState: includeOrchestratorState,
            includeSecrets: includeSecrets,
            compressionEnabled: compressionEnabled,
            encryptionEnabled: encryptionEnabled
        )
        
        Task {
            let result = await backupManager.createBackup(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                settings: settings
            )
            
            DispatchQueue.main.async {
                self.isCreating = false
                
                switch result {
                case .success:
                    self.dismiss()
                case .failure(let error):
                    // Show error alert
                    break
                }
            }
        }
    }
}

// MARK: - Restore Backup View
struct RestoreBackupView: View {
    let backup: BackupConfiguration
    @Environment(\.dismiss) private var dismiss
    @StateObject private var backupManager = BackupManager.shared
    
    @State private var restoreSettings = true
    @State private var restoreServerConfigs = true
    @State private var restoreOrchestratorState = true
    @State private var overwriteExisting = true
    @State private var createBackupBeforeRestore = true
    @State private var isRestoring = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Backup Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Backup Information")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Name", value: backup.name)
                        InfoRow(label: "Created", value: backup.formattedTimestamp)
                        InfoRow(label: "Size", value: backup.size)
                        InfoRow(label: "Version", value: backup.version)
                        
                        if !backup.description.isEmpty {
                            InfoRow(label: "Description", value: backup.description)
                        }
                    }
                }
                
                // Restore Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("What to Restore")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Application Settings", isOn: $restoreSettings)
                            .disabled(!backup.settings.includeSettings)
                        
                        Toggle("Server Configurations", isOn: $restoreServerConfigs)
                            .disabled(!backup.settings.includeServerConfigs)
                        
                        Toggle("Orchestrator State", isOn: $restoreOrchestratorState)
                            .disabled(!backup.settings.includeOrchestratorState)
                    }
                }
                
                // Safety Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Safety Options")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Create backup before restore", isOn: $createBackupBeforeRestore)
                        Toggle("Overwrite existing configurations", isOn: $overwriteExisting)
                    }
                }
                
                // Warning
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        
                        Text("Warning")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Restoring will replace your current configuration. Make sure you have a recent backup if needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
                
                // Action buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Restore") {
                        restoreBackup()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRestoring)
                }
            }
            .padding()
            .navigationTitle("Restore Backup")
            .disabled(isRestoring)
            .overlay {
                if isRestoring {
                    Color.black.opacity(0.3)
                        .overlay {
                            VStack {
                                ProgressView()
                                Text("Restoring backup...")
                                    .padding(.top, 8)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func restoreBackup() {
        isRestoring = true
        
        let options = RestoreOptions(
            restoreSettings: restoreSettings,
            restoreServerConfigs: restoreServerConfigs,
            restoreOrchestratorState: restoreOrchestratorState,
            overwriteExisting: overwriteExisting,
            createBackupBeforeRestore: createBackupBeforeRestore
        )
        
        Task {
            let result = await backupManager.restoreBackup(backup, options: options)
            
            DispatchQueue.main.async {
                self.isRestoring = false
                
                switch result {
                case .success:
                    self.dismiss()
                case .failure(let error):
                    // Show error alert
                    break
                }
            }
        }
    }
}

// MARK: - Backup Detail View
struct BackupDetailView: View {
    let backup: BackupConfiguration
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Basic Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Backup Details")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Name", value: backup.name)
                        InfoRow(label: "Description", value: backup.description.isEmpty ? "No description" : backup.description)
                        InfoRow(label: "Created", value: backup.formattedTimestamp)
                        InfoRow(label: "Size", value: backup.size)
                        InfoRow(label: "Version", value: backup.version)
                        InfoRow(label: "Checksum", value: String(backup.checksum.prefix(12)) + "...")
                    }
                }
                
                // Contents
                VStack(alignment: .leading, spacing: 12) {
                    Text("Backup Contents")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        BackupContentRow(
                            icon: "gear",
                            title: "Application Settings",
                            included: backup.settings.includeSettings
                        )
                        
                        BackupContentRow(
                            icon: "server.rack",
                            title: "Server Configurations",
                            included: backup.settings.includeServerConfigs,
                            detail: "\(backup.servers.count) servers"
                        )
                        
                        BackupContentRow(
                            icon: "cpu",
                            title: "Orchestrator State",
                            included: backup.settings.includeOrchestratorState,
                            detail: "\(backup.orchestratorState.activeServers.count) active servers"
                        )
                        
                        BackupContentRow(
                            icon: "lock",
                            title: "Encrypted Credentials",
                            included: backup.settings.includeSecrets
                        )
                    }
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Backup Settings")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SettingRow(
                            title: "Compression",
                            enabled: backup.settings.compressionEnabled
                        )
                        
                        SettingRow(
                            title: "Encryption",
                            enabled: backup.settings.encryptionEnabled
                        )
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Backup Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
        .font(.caption)
    }
}

struct BackupContentRow: View {
    let icon: String
    let title: String
    let included: Bool
    let detail: String?
    
    init(icon: String, title: String, included: Bool, detail: String? = nil) {
        self.icon = icon
        self.title = title
        self.included = included
        self.detail = detail
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(included ? .green : .gray)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(included ? .primary : .secondary)
            
            if let detail = detail, included {
                Text("(\(detail))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(included ? .green : .gray)
        }
        .font(.caption)
    }
}

struct SettingRow: View {
    let title: String
    let enabled: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(enabled ? .primary : .secondary)
            
            Spacer()
            
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .green : .gray)
        }
        .font(.caption)
    }
}

// MARK: - Preview
struct BackupRestoreView_Previews: PreviewProvider {
    static var previews: some View {
        BackupRestoreView()
            .frame(width: 800, height: 600)
    }
} 