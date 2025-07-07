package analytics

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"
)

// ToolCall represents a single tool execution
type ToolCall struct {
	ID           string                 `json:"id"`
	ToolName     string                 `json:"tool_name"`
	ServerID     string                 `json:"server_id"`
	ProfileID    string                 `json:"profile_id"`
	Arguments    map[string]interface{} `json:"arguments"`
	StartTime    time.Time              `json:"start_time"`
	EndTime      time.Time              `json:"end_time"`
	Duration     time.Duration          `json:"duration"`
	Success      bool                   `json:"success"`
	ErrorMessage string                 `json:"error_message,omitempty"`
	ResponseSize int                    `json:"response_size"`
	UserAgent    string                 `json:"user_agent,omitempty"`
	ClientIP     string                 `json:"client_ip,omitempty"`
}

// ServerMetrics represents performance metrics for a server
type ServerMetrics struct {
	ServerID        string        `json:"server_id"`
	TotalCalls      int           `json:"total_calls"`
	SuccessfulCalls int           `json:"successful_calls"`
	FailedCalls     int           `json:"failed_calls"`
	AvgResponseTime time.Duration `json:"avg_response_time"`
	MinResponseTime time.Duration `json:"min_response_time"`
	MaxResponseTime time.Duration `json:"max_response_time"`
	TotalDataSize   int64         `json:"total_data_size"`
	LastCall        time.Time     `json:"last_call"`
	Status          string        `json:"status"` // "healthy", "degraded", "down"
	SuccessRate     float64       `json:"success_rate"`
}

// ToolMetrics represents usage metrics for a specific tool
type ToolMetrics struct {
	ToolName        string        `json:"tool_name"`
	ServerID        string        `json:"server_id"`
	Category        string        `json:"category"`
	TotalCalls      int           `json:"total_calls"`
	SuccessfulCalls int           `json:"successful_calls"`
	FailedCalls     int           `json:"failed_calls"`
	AvgResponseTime time.Duration `json:"avg_response_time"`
	LastUsed        time.Time     `json:"last_used"`
	SuccessRate     float64       `json:"success_rate"`
	PopularityRank  int           `json:"popularity_rank"`
}

// Analytics represents overall analytics data
type Analytics struct {
	GeneratedAt        time.Time       `json:"generated_at"`
	Period             string          `json:"period"` // "hourly", "daily", "weekly", "monthly"
	TotalToolCalls     int             `json:"total_tool_calls"`
	TotalServers       int             `json:"total_servers"`
	ActiveServers      int             `json:"active_servers"`
	AvgResponseTime    time.Duration   `json:"avg_response_time"`
	SuccessRate        float64         `json:"success_rate"`
	TopTools           []ToolMetrics   `json:"top_tools"`
	ServerMetrics      []ServerMetrics `json:"server_metrics"`
	ProfileUsage       map[string]int  `json:"profile_usage"`
	HourlyDistribution map[int]int     `json:"hourly_distribution"`
	DailyDistribution  map[string]int  `json:"daily_distribution"`
}

// Insights represents actionable insights from analytics
type Insights struct {
	GeneratedAt     time.Time              `json:"generated_at"`
	Recommendations []Recommendation       `json:"recommendations"`
	Alerts          []Alert                `json:"alerts"`
	TrendAnalysis   TrendAnalysis          `json:"trend_analysis"`
	ServerHealth    map[string]HealthScore `json:"server_health"`
}

// Recommendation represents an actionable recommendation
type Recommendation struct {
	Type        string    `json:"type"`     // "performance", "usage", "configuration"
	Priority    string    `json:"priority"` // "high", "medium", "low"
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Action      string    `json:"action"`
	Impact      string    `json:"impact"`
	CreatedAt   time.Time `json:"created_at"`
}

// Alert represents a system alert
type Alert struct {
	Type        string    `json:"type"`     // "error", "performance", "availability"
	Severity    string    `json:"severity"` // "critical", "warning", "info"
	Title       string    `json:"title"`
	Description string    `json:"description"`
	ServerID    string    `json:"server_id,omitempty"`
	ToolName    string    `json:"tool_name,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	Resolved    bool      `json:"resolved"`
}

// TrendAnalysis represents trend analysis data
type TrendAnalysis struct {
	UsageTrend        string  `json:"usage_trend"`       // "increasing", "decreasing", "stable"
	PerformanceTrend  string  `json:"performance_trend"` // "improving", "degrading", "stable"
	ErrorRateTrend    string  `json:"error_rate_trend"`  // "increasing", "decreasing", "stable"
	GrowthRate        float64 `json:"growth_rate"`
	PerformanceChange float64 `json:"performance_change"`
	ErrorRateChange   float64 `json:"error_rate_change"`
}

// HealthScore represents a server health score
type HealthScore struct {
	Score          float64   `json:"score"`  // 0-100
	Status         string    `json:"status"` // "excellent", "good", "fair", "poor"
	Factors        []string  `json:"factors"`
	LastAssessment time.Time `json:"last_assessment"`
}

// Tracker manages analytics tracking
type Tracker struct {
	dataDir string
	calls   []ToolCall
	mu      sync.RWMutex
	config  TrackerConfig
}

// TrackerConfig defines analytics configuration
type TrackerConfig struct {
	Enabled           bool          `json:"enabled"`
	RetentionDays     int           `json:"retention_days"`
	FlushInterval     time.Duration `json:"flush_interval"`
	MaxMemoryCalls    int           `json:"max_memory_calls"`
	EnableDetailedLog bool          `json:"enable_detailed_log"`
}

// NewTracker creates a new analytics tracker
func NewTracker(dataDir string, config TrackerConfig) *Tracker {
	tracker := &Tracker{
		dataDir: dataDir,
		calls:   make([]ToolCall, 0),
		config:  config,
	}

	// Create analytics directory
	os.MkdirAll(filepath.Join(dataDir, "analytics"), 0755)

	// Start background tasks
	if config.Enabled {
		go tracker.flushWorker()
		go tracker.cleanupWorker()
	}

	return tracker
}

// TrackToolCall tracks a tool call execution
func (t *Tracker) TrackToolCall(call ToolCall) {
	if !t.config.Enabled {
		return
	}

	t.mu.Lock()
	defer t.mu.Unlock()

	call.Duration = call.EndTime.Sub(call.StartTime)
	t.calls = append(t.calls, call)

	// Flush if memory limit reached
	if len(t.calls) >= t.config.MaxMemoryCalls {
		t.flushToDisk()
	}
}

// StartToolCall creates a tool call entry for tracking
func (t *Tracker) StartToolCall(toolName, serverID, profileID string, args map[string]interface{}) *ToolCall {
	return &ToolCall{
		ID:        fmt.Sprintf("%d-%s", time.Now().UnixNano(), toolName),
		ToolName:  toolName,
		ServerID:  serverID,
		ProfileID: profileID,
		Arguments: args,
		StartTime: time.Now(),
	}
}

// CompleteToolCall marks a tool call as completed
func (t *Tracker) CompleteToolCall(call *ToolCall, success bool, errorMsg string, responseSize int) {
	call.EndTime = time.Now()
	call.Success = success
	call.ErrorMessage = errorMsg
	call.ResponseSize = responseSize

	t.TrackToolCall(*call)
}

// GetAnalytics generates analytics for a given period
func (t *Tracker) GetAnalytics(period string, days int) (*Analytics, error) {
	t.mu.RLock()
	defer t.mu.RUnlock()

	// Load historical data
	calls, err := t.loadCalls(days)
	if err != nil {
		return nil, err
	}

	// Combine with in-memory calls
	allCalls := append(calls, t.calls...)

	return t.generateAnalytics(allCalls, period), nil
}

// generateAnalytics creates analytics from tool calls
func (t *Tracker) generateAnalytics(calls []ToolCall, period string) *Analytics {
	analytics := &Analytics{
		GeneratedAt:        time.Now(),
		Period:             period,
		TotalToolCalls:     len(calls),
		ProfileUsage:       make(map[string]int),
		HourlyDistribution: make(map[int]int),
		DailyDistribution:  make(map[string]int),
	}

	if len(calls) == 0 {
		return analytics
	}

	// Track servers and success rates
	serverMap := make(map[string]bool)
	toolMap := make(map[string]*ToolMetrics)
	serverMetricsMap := make(map[string]*ServerMetrics)

	successCount := 0
	totalDuration := time.Duration(0)

	for _, call := range calls {
		serverMap[call.ServerID] = true

		// Track success rate
		if call.Success {
			successCount++
		}
		totalDuration += call.Duration

		// Track profile usage
		analytics.ProfileUsage[call.ProfileID]++

		// Track hourly distribution
		hour := call.StartTime.Hour()
		analytics.HourlyDistribution[hour]++

		// Track daily distribution
		day := call.StartTime.Format("2006-01-02")
		analytics.DailyDistribution[day]++

		// Track tool metrics
		toolKey := fmt.Sprintf("%s:%s", call.ServerID, call.ToolName)
		if _, exists := toolMap[toolKey]; !exists {
			toolMap[toolKey] = &ToolMetrics{
				ToolName: call.ToolName,
				ServerID: call.ServerID,
			}
		}

		toolMetric := toolMap[toolKey]
		toolMetric.TotalCalls++
		if call.Success {
			toolMetric.SuccessfulCalls++
		} else {
			toolMetric.FailedCalls++
		}
		toolMetric.LastUsed = call.StartTime

		// Track server metrics
		if _, exists := serverMetricsMap[call.ServerID]; !exists {
			serverMetricsMap[call.ServerID] = &ServerMetrics{
				ServerID:        call.ServerID,
				MinResponseTime: call.Duration,
				MaxResponseTime: call.Duration,
			}
		}

		serverMetric := serverMetricsMap[call.ServerID]
		serverMetric.TotalCalls++
		if call.Success {
			serverMetric.SuccessfulCalls++
		} else {
			serverMetric.FailedCalls++
		}

		if call.Duration < serverMetric.MinResponseTime {
			serverMetric.MinResponseTime = call.Duration
		}
		if call.Duration > serverMetric.MaxResponseTime {
			serverMetric.MaxResponseTime = call.Duration
		}

		serverMetric.TotalDataSize += int64(call.ResponseSize)
		serverMetric.LastCall = call.StartTime
	}

	// Calculate overall metrics
	analytics.TotalServers = len(serverMap)
	analytics.ActiveServers = len(serverMetricsMap)
	if len(calls) > 0 {
		analytics.AvgResponseTime = totalDuration / time.Duration(len(calls))
		analytics.SuccessRate = float64(successCount) / float64(len(calls)) * 100
	}

	// Convert maps to slices and calculate rates
	for _, toolMetric := range toolMap {
		if toolMetric.TotalCalls > 0 {
			toolMetric.SuccessRate = float64(toolMetric.SuccessfulCalls) / float64(toolMetric.TotalCalls) * 100
		}
	}

	for _, serverMetric := range serverMetricsMap {
		if serverMetric.TotalCalls > 0 {
			serverMetric.SuccessRate = float64(serverMetric.SuccessfulCalls) / float64(serverMetric.TotalCalls) * 100
			serverMetric.AvgResponseTime = totalDuration / time.Duration(serverMetric.TotalCalls)
		}

		// Determine server status
		if serverMetric.SuccessRate >= 95 {
			serverMetric.Status = "healthy"
		} else if serverMetric.SuccessRate >= 80 {
			serverMetric.Status = "degraded"
		} else {
			serverMetric.Status = "down"
		}
	}

	// Sort tools by popularity
	toolSlice := make([]ToolMetrics, 0, len(toolMap))
	for _, tool := range toolMap {
		toolSlice = append(toolSlice, *tool)
	}
	sort.Slice(toolSlice, func(i, j int) bool {
		return toolSlice[i].TotalCalls > toolSlice[j].TotalCalls
	})

	// Set popularity ranks and get top tools
	for i := range toolSlice {
		toolSlice[i].PopularityRank = i + 1
	}

	if len(toolSlice) > 10 {
		analytics.TopTools = toolSlice[:10]
	} else {
		analytics.TopTools = toolSlice
	}

	// Convert server metrics to slice
	for _, serverMetric := range serverMetricsMap {
		analytics.ServerMetrics = append(analytics.ServerMetrics, *serverMetric)
	}

	return analytics
}

// GetInsights generates actionable insights from analytics
func (t *Tracker) GetInsights(days int) (*Insights, error) {
	analytics, err := t.GetAnalytics("daily", days)
	if err != nil {
		return nil, err
	}

	insights := &Insights{
		GeneratedAt:     time.Now(),
		Recommendations: make([]Recommendation, 0),
		Alerts:          make([]Alert, 0),
		ServerHealth:    make(map[string]HealthScore),
	}

	// Generate recommendations based on analytics
	t.generateRecommendations(analytics, insights)
	t.generateAlerts(analytics, insights)
	t.generateHealthScores(analytics, insights)
	t.generateTrendAnalysis(analytics, insights)

	return insights, nil
}

// generateRecommendations creates recommendations based on analytics
func (t *Tracker) generateRecommendations(analytics *Analytics, insights *Insights) {
	// Performance recommendations
	if analytics.AvgResponseTime > 10*time.Second {
		insights.Recommendations = append(insights.Recommendations, Recommendation{
			Type:        "performance",
			Priority:    "high",
			Title:       "High Average Response Time",
			Description: fmt.Sprintf("Average response time is %.2fs, consider optimizing server performance", analytics.AvgResponseTime.Seconds()),
			Action:      "Enable caching and optimize server configurations",
			Impact:      "Improved user experience and faster tool responses",
			CreatedAt:   time.Now(),
		})
	}

	// Usage recommendations
	if len(analytics.TopTools) > 0 && analytics.TopTools[0].TotalCalls > analytics.TotalToolCalls/2 {
		insights.Recommendations = append(insights.Recommendations, Recommendation{
			Type:        "usage",
			Priority:    "medium",
			Title:       "Heavy Tool Usage Concentration",
			Description: fmt.Sprintf("Tool '%s' accounts for over 50%% of usage", analytics.TopTools[0].ToolName),
			Action:      "Consider load balancing or scaling this specific tool",
			Impact:      "Better resource distribution and improved reliability",
			CreatedAt:   time.Now(),
		})
	}

	// Configuration recommendations
	if analytics.SuccessRate < 95 {
		insights.Recommendations = append(insights.Recommendations, Recommendation{
			Type:        "configuration",
			Priority:    "high",
			Title:       "Low Success Rate",
			Description: fmt.Sprintf("Overall success rate is %.1f%%, investigate failing tools", analytics.SuccessRate),
			Action:      "Review error logs and improve error handling",
			Impact:      "Higher reliability and better user experience",
			CreatedAt:   time.Now(),
		})
	}
}

// generateAlerts creates alerts based on analytics
func (t *Tracker) generateAlerts(analytics *Analytics, insights *Insights) {
	for _, serverMetric := range analytics.ServerMetrics {
		if serverMetric.Status == "down" {
			insights.Alerts = append(insights.Alerts, Alert{
				Type:        "availability",
				Severity:    "critical",
				Title:       "Server Down",
				Description: fmt.Sprintf("Server %s has very low success rate (%.1f%%)", serverMetric.ServerID, serverMetric.SuccessRate),
				ServerID:    serverMetric.ServerID,
				CreatedAt:   time.Now(),
				Resolved:    false,
			})
		} else if serverMetric.Status == "degraded" {
			insights.Alerts = append(insights.Alerts, Alert{
				Type:        "performance",
				Severity:    "warning",
				Title:       "Server Performance Degraded",
				Description: fmt.Sprintf("Server %s has degraded performance (%.1f%% success rate)", serverMetric.ServerID, serverMetric.SuccessRate),
				ServerID:    serverMetric.ServerID,
				CreatedAt:   time.Now(),
				Resolved:    false,
			})
		}
	}
}

// generateHealthScores calculates health scores for servers
func (t *Tracker) generateHealthScores(analytics *Analytics, insights *Insights) {
	for _, serverMetric := range analytics.ServerMetrics {
		score := t.calculateHealthScore(serverMetric)
		status := "excellent"

		if score < 60 {
			status = "poor"
		} else if score < 75 {
			status = "fair"
		} else if score < 90 {
			status = "good"
		}

		factors := []string{}
		if serverMetric.SuccessRate < 95 {
			factors = append(factors, "low success rate")
		}
		if serverMetric.AvgResponseTime > 5*time.Second {
			factors = append(factors, "high response time")
		}
		if time.Since(serverMetric.LastCall) > 24*time.Hour {
			factors = append(factors, "inactive")
		}

		insights.ServerHealth[serverMetric.ServerID] = HealthScore{
			Score:          score,
			Status:         status,
			Factors:        factors,
			LastAssessment: time.Now(),
		}
	}
}

// calculateHealthScore calculates a health score for a server
func (t *Tracker) calculateHealthScore(metric ServerMetrics) float64 {
	score := 0.0

	// Success rate (40% of score)
	score += (metric.SuccessRate / 100.0) * 40

	// Response time (30% of score)
	responseScore := 30.0
	if metric.AvgResponseTime > 10*time.Second {
		responseScore = 10.0
	} else if metric.AvgResponseTime > 5*time.Second {
		responseScore = 20.0
	}
	score += responseScore

	// Activity (20% of score)
	hoursSinceLastCall := time.Since(metric.LastCall).Hours()
	if hoursSinceLastCall < 1 {
		score += 20
	} else if hoursSinceLastCall < 24 {
		score += 15
	} else if hoursSinceLastCall < 168 { // 1 week
		score += 10
	}

	// Volume (10% of score)
	if metric.TotalCalls > 100 {
		score += 10
	} else if metric.TotalCalls > 10 {
		score += 5
	}

	return score
}

// generateTrendAnalysis analyzes trends in the data
func (t *Tracker) generateTrendAnalysis(analytics *Analytics, insights *Insights) {
	// For now, provide basic trend analysis
	// In a real implementation, this would compare with historical data
	insights.TrendAnalysis = TrendAnalysis{
		UsageTrend:        "stable",
		PerformanceTrend:  "stable",
		ErrorRateTrend:    "stable",
		GrowthRate:        0.0,
		PerformanceChange: 0.0,
		ErrorRateChange:   0.0,
	}
}

// flushWorker periodically flushes data to disk
func (t *Tracker) flushWorker() {
	ticker := time.NewTicker(t.config.FlushInterval)
	defer ticker.Stop()

	for range ticker.C {
		t.mu.Lock()
		if len(t.calls) > 0 {
			t.flushToDisk()
		}
		t.mu.Unlock()
	}
}

// cleanupWorker periodically cleans up old data
func (t *Tracker) cleanupWorker() {
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()

	for range ticker.C {
		t.cleanupOldData()
	}
}

// flushToDisk saves current calls to disk
func (t *Tracker) flushToDisk() {
	if len(t.calls) == 0 {
		return
	}

	today := time.Now().Format("2006-01-02")
	filename := filepath.Join(t.dataDir, "analytics", fmt.Sprintf("calls-%s.json", today))

	// Load existing calls for today
	var existingCalls []ToolCall
	if data, err := os.ReadFile(filename); err == nil {
		json.Unmarshal(data, &existingCalls)
	}

	// Append new calls
	allCalls := append(existingCalls, t.calls...)

	// Save to disk
	data, err := json.MarshalIndent(allCalls, "", "  ")
	if err == nil {
		os.WriteFile(filename, data, 0644)
	}

	// Clear memory
	t.calls = t.calls[:0]
}

// loadCalls loads historical calls from disk
func (t *Tracker) loadCalls(days int) ([]ToolCall, error) {
	var allCalls []ToolCall

	for i := 0; i < days; i++ {
		date := time.Now().AddDate(0, 0, -i).Format("2006-01-02")
		filename := filepath.Join(t.dataDir, "analytics", fmt.Sprintf("calls-%s.json", date))

		if data, err := os.ReadFile(filename); err == nil {
			var dayCalls []ToolCall
			if json.Unmarshal(data, &dayCalls) == nil {
				allCalls = append(allCalls, dayCalls...)
			}
		}
	}

	return allCalls, nil
}

// cleanupOldData removes data older than retention period
func (t *Tracker) cleanupOldData() {
	cutoffDate := time.Now().AddDate(0, 0, -t.config.RetentionDays)

	analyticsDir := filepath.Join(t.dataDir, "analytics")
	entries, err := os.ReadDir(analyticsDir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		// Parse date from filename
		name := entry.Name()
		if len(name) >= 16 && name[:6] == "calls-" && name[16:] == ".json" {
			dateStr := name[6:16]
			if date, err := time.Parse("2006-01-02", dateStr); err == nil {
				if date.Before(cutoffDate) {
					os.Remove(filepath.Join(analyticsDir, name))
				}
			}
		}
	}
}
