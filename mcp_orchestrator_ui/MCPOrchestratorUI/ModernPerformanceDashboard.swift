import SwiftUI
import Charts

enum TrendDirection {
    case up
    case down
    case stable
    
    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return DesignSystem.Colors.statusSuccess
        case .down: return DesignSystem.Colors.statusError
        case .stable: return DesignSystem.Colors.textSecondary
        }
    }
}

// MARK: - Performance Metric
struct PerformanceMetric: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let category: String
}

// MARK: - System Health Status
enum SystemHealthStatus: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .excellent: return DesignSystem.Colors.success
        case .good: return Color.green.opacity(0.8)
        case .fair: return DesignSystem.Colors.warning
        case .poor: return Color.orange.opacity(0.8)
        case .critical: return DesignSystem.Colors.error
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}

// MARK: - Modern Performance Dashboard
struct ModernPerformanceDashboard: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var selectedTimeRange = TimeRange.hour
    @State private var selectedMetric = MetricType.cpu
    @State private var showingSettings = false
    @State private var showingAlertDetail: PerformanceAlert? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header with Controls
                headerSection
                
                // Main Content
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Performance Cards
                        performanceCardsSection
                        
                        // System Health Overview
                        systemHealthSection
                        
                        // Quick Actions
                        quickActionsSection
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .background(DesignSystem.Colors.backgroundBase)
            .navigationTitle("Performance")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: DesignSystem.Icons.settings)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            PerformanceSettingsSheet()
        }
        .sheet(item: $showingAlertDetail) { alert in
            AlertDetailSheet(alert: alert)
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("System Performance")
                    .font(DesignSystem.Typography.headlineLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Real-time monitoring and insights")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: DesignSystem.Spacing.md) {
                // Time Range Picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                // Refresh Button
                Button(action: refreshMetrics) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(ModernSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.md)
    }
    
    private var performanceCardsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.md), count: 4), spacing: DesignSystem.Spacing.md) {
            PerformanceCard(
                title: "CPU Usage",
                value: "45%",
                trend: .stable,
                color: DesignSystem.Colors.chartCpu
            )
            
            PerformanceCard(
                title: "Memory",
                value: "67%",
                trend: .up,
                color: DesignSystem.Colors.chartMemory
            )
            
            PerformanceCard(
                title: "Network",
                value: "12.3 MB/s",
                trend: .down,
                color: DesignSystem.Colors.chartNetwork
            )
            
            PerformanceCard(
                title: "Disk I/O",
                value: "8.9 MB/s",
                trend: .stable,
                color: DesignSystem.Colors.chartDisk
            )
        }
    }
    
    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("System Health")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                ModernStatusBadge(status: .healthy)
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                HealthMetricRow(
                    icon: "cpu",
                    label: "CPU Temperature",
                    value: "52°C",
                    status: .normal
                )
                
                HealthMetricRow(
                    icon: "memorychip",
                    label: "Memory Pressure",
                    value: "Low",
                    status: .normal
                )
                
                HealthMetricRow(
                    icon: "network",
                    label: "Network Latency",
                    value: "12ms",
                    status: .normal
                )
                
                HealthMetricRow(
                    icon: "externaldrive",
                    label: "Disk Health",
                    value: "Excellent",
                    status: .normal
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surfaceElevated)
        .cornerRadius(DesignSystem.Layout.cornerRadius)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Quick Actions")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                ActionButton(
                    icon: "arrow.clockwise",
                    title: "Refresh Data",
                    action: refreshMetrics
                )
                
                ActionButton(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "View Details",
                    action: { /* Navigate to detailed view */ }
                )
                
                ActionButton(
                    icon: "gear",
                    title: "Settings",
                    action: { showingSettings = true }
                )
                
                ActionButton(
                    icon: "square.and.arrow.up",
                    title: "Export Data",
                    action: { /* Export functionality */ }
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surfaceElevated)
        .cornerRadius(DesignSystem.Layout.cornerRadius)
    }
    
    private func refreshMetrics() {
        // Refresh performance data
        print("Refreshing performance metrics...")
    }
}

// MARK: - Supporting Views

struct PerformanceCard: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(trend.color)
            }
            
            Text(value)
                .font(DesignSystem.Typography.headlineLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)
            
            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * 0.6, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceElevated)
        .cornerRadius(DesignSystem.Layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct HealthMetricRow: View {
    let icon: String
    let label: String
    let value: String
    let status: HealthStatus
    
    enum HealthStatus {
        case normal, warning, critical
        
        var color: Color {
            switch self {
            case .normal: return DesignSystem.Colors.statusSuccess
            case .warning: return DesignSystem.Colors.statusWarning
            case .critical: return DesignSystem.Colors.statusError
            }
        }
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(status.color)
                .frame(width: 24)
            
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fontWeight(.medium)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                
                Text(title)
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.backgroundBase)
            .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernStatusBadge: View {
    enum Status {
        case healthy, degraded, unhealthy
        
        var color: Color {
            switch self {
            case .healthy: return DesignSystem.Colors.statusSuccess
            case .degraded: return DesignSystem.Colors.statusWarning
            case .unhealthy: return DesignSystem.Colors.statusError
            }
        }
        
        var text: String {
            switch self {
            case .healthy: return "Healthy"
            case .degraded: return "Degraded"
            case .unhealthy: return "Unhealthy"
            }
        }
    }
    
    let status: Status
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(status.text)
                .font(DesignSystem.Typography.captionMedium)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(status.color.opacity(0.1))
        .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
    }
}

// MARK: - Settings Sheet

struct PerformanceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Performance monitoring settings coming soon...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .navigationTitle("Performance Settings")
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

// MARK: - Alert Detail Sheet

struct AlertDetailSheet: View {
    let alert: PerformanceAlert
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Alert details coming soon...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .navigationTitle("Alert Details")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Supporting Types

enum TimeRange: String, CaseIterable {
    case minute = "1m"
    case hour = "1h"
    case day = "1d"
    case week = "1w"
    
    var displayName: String {
        switch self {
        case .minute: return "1 Min"
        case .hour: return "1 Hour"
        case .day: return "1 Day"
        case .week: return "1 Week"
        }
    }
}

enum MetricType: String, CaseIterable {
    case cpu = "CPU"
    case memory = "Memory"
    case network = "Network"
    case disk = "Disk"
}

// MARK: - Button Styles

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.surfaceElevated)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Preview

struct ModernPerformanceDashboard_Previews: PreviewProvider {
    static var previews: some View {
        ModernPerformanceDashboard()
            .frame(width: 1000, height: 700)
    }
} 