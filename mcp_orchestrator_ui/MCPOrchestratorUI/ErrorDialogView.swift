import SwiftUI

struct ErrorDialogView: View {
    let errorReport: ErrorReport
    @StateObject private var errorManager = ErrorHandlingManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isExecutingRecovery = false
    @State private var selectedRecoveryAction: RecoveryAction?
    
    private var recoveryActions: [RecoveryAction] {
        errorManager.getRecoveryActions(for: errorReport.error)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: errorReport.error.severity.icon)
                    .font(.title)
                    .foregroundColor(errorReport.error.severity.color)
                    .frame(width: 32, height: 32)
                    .background(errorReport.error.severity.color.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error Occurred")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(errorReport.error.severity.rawValue + " • " + errorReport.error.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if errorReport.retryCount > 0 {
                    Text("Retry \(errorReport.retryCount)/3")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            // Error description
            VStack(alignment: .leading, spacing: 8) {
                Text("What happened:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(errorReport.error.localizedDescription)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Recovery suggestion
            if let suggestion = errorReport.error.recoverySuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to fix it:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(suggestion)
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Recovery actions
            if !recoveryActions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recovery Options:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(Array(recoveryActions.enumerated()), id: \.offset) { index, action in
                            RecoveryActionButton(
                                action: action,
                                isExecuting: isExecutingRecovery && selectedRecoveryAction?.title == action.title
                            ) {
                                executeRecoveryAction(action)
                            }
                        }
                    }
                }
            }
            
            // Context information (expandable)
            if !errorReport.context.isEmpty {
                DisclosureGroup("Technical Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(errorReport.context.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key + ":")
                                    .fontWeight(.medium)
                                    .frame(width: 100, alignment: .leading)
                                Text(errorReport.context[key] ?? "")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .font(.caption)
                        }
                        
                        if let userAction = errorReport.userAction {
                            HStack {
                                Text("User Action:")
                                    .fontWeight(.medium)
                                    .frame(width: 100, alignment: .leading)
                                Text(userAction)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .font(.caption)
                        }
                        
                        HStack {
                            Text("Time:")
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            Text(errorReport.formattedTimestamp)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            // Action buttons
            HStack {
                Button("Ignore") {
                    errorManager.resolveError(errorReport.id)
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if errorReport.error.canRetry {
                    Button("Retry") {
                        executeGenericRetry()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExecutingRecovery)
                } else {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func executeRecoveryAction(_ action: RecoveryAction) {
        isExecutingRecovery = true
        selectedRecoveryAction = action
        
        Task {
            let success = await action.action()
            
            DispatchQueue.main.async {
                self.isExecutingRecovery = false
                self.selectedRecoveryAction = nil
                
                if success {
                    self.errorManager.resolveError(self.errorReport.id)
                    self.dismiss()
                }
            }
        }
    }
    
    private func executeGenericRetry() {
        isExecutingRecovery = true
        
        Task {
            // Simulate retry logic
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let success = Bool.random()
            
            DispatchQueue.main.async {
                self.isExecutingRecovery = false
                
                if success {
                    self.errorManager.resolveError(self.errorReport.id)
                    self.dismiss()
                }
            }
        }
    }
}

// MARK: - Recovery Action Button
struct RecoveryActionButton: View {
    let action: RecoveryAction
    let isExecuting: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: action.isDestructive ? "exclamationmark.triangle" : "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(action.isDestructive ? .red : .blue)
                }
                
                VStack(spacing: 2) {
                    Text(action.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(action.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(action.isDestructive ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(action.isDestructive ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isExecuting)
    }
}

// MARK: - Error List View
struct ErrorListView: View {
    @StateObject private var errorManager = ErrorHandlingManager.shared
    @State private var selectedError: ErrorReport?
    @State private var showingErrorDetail = false
    @State private var showingStatistics = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Header
                HStack {
                    Text("Error Management")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("Statistics") {
                        showingStatistics = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                // Current errors
                if !errorManager.currentErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Errors (\(errorManager.currentErrors.count))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(errorManager.currentErrors) { error in
                                ErrorRowView(error: error) {
                                    selectedError = error
                                    showingErrorDetail = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding()
                }
                
                // Error history
                VStack(alignment: .leading, spacing: 12) {
                    Text("Error History (\(errorManager.errorHistory.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if errorManager.errorHistory.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            
                            Text("No errors recorded")
                                .font(.title2)
                                .foregroundColor(.green)
                            
                            Text("Your system is running smoothly!")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(errorManager.errorHistory.reversed()) { error in
                                    ErrorRowView(error: error) {
                                        selectedError = error
                                        showingErrorDetail = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingErrorDetail) {
            if let error = selectedError {
                ErrorDialogView(errorReport: error)
            }
        }
        .sheet(isPresented: $showingStatistics) {
            ErrorStatisticsView()
        }
    }
}

// MARK: - Error Row View
struct ErrorRowView: View {
    let error: ErrorReport
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            VStack {
                Image(systemName: error.error.severity.icon)
                    .foregroundColor(error.error.severity.color)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(error.error.severity.color.opacity(0.1))
                    .cornerRadius(6)
                
                if error.resolved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(error.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(error.error.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    if error.retryCount > 0 {
                        Text("Retry \(error.retryCount)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(error.error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let suggestion = error.error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if error.error.canRetry && !error.resolved {
                Button("Retry") {
                    // Handle retry
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(error.resolved ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(error.resolved ? Color.green.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Error Statistics View
struct ErrorStatisticsView: View {
    @StateObject private var errorManager = ErrorHandlingManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private var statistics: ErrorStatistics {
        errorManager.getErrorStatistics()
    }
    
    private var sortedCategories: [ErrorCategory] {
        Array(statistics.errorsByCategory.keys.sorted(by: { $0.rawValue < $1.rawValue }))
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Overview
                VStack(alignment: .leading, spacing: 16) {
                    Text("Error Overview")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        StatisticCard(
                            title: "Total Errors",
                            value: "\(statistics.totalErrors)",
                            color: .blue
                        )
                        
                        StatisticCard(
                            title: "Resolved",
                            value: "\(statistics.resolvedErrors)",
                            color: .green
                        )
                        
                        StatisticCard(
                            title: "Resolution Rate",
                            value: String(format: "%.1f%%", statistics.resolutionRate * 100),
                            color: .orange
                        )
                    }
                }
                
                // By Category
                VStack(alignment: .leading, spacing: 16) {
                    Text("Errors by Category")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(sortedCategories, id: \.self) { category in
                            HStack {
                                Text(category.rawValue)
                                    .font(.caption)
                                Spacer()
                                Text("\(statistics.errorsByCategory[category] ?? 0)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // By Severity
                VStack(alignment: .leading, spacing: 16) {
                    Text("Errors by Severity")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(ErrorSeverity.allCases, id: \.self) { severity in
                            HStack {
                                Image(systemName: severity.icon)
                                    .foregroundColor(severity.color)
                                Text(severity.rawValue)
                                    .font(.caption)
                                Spacer()
                                Text("\(statistics.errorsBySeverity[severity] ?? 0)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(severity.color)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(severity.color.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Error Statistics")
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

// MARK: - Statistic Card
struct StatisticCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview
struct ErrorDialogView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleError = ErrorReport(
            timestamp: Date(),
            error: .serverConnection(serverName: "GitHub", details: "Connection refused"),
            context: ["server_id": "github-1", "retry_count": "2"],
            stackTrace: nil,
            userAction: "Clicked refresh button",
            resolved: false,
            retryCount: 2
        )
        
        ErrorDialogView(errorReport: sampleError)
            .frame(width: 600, height: 500)
    }
} 