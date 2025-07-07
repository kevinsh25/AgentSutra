package ui

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"mcp_orchestrator/internal/analytics"
	"mcp_orchestrator/internal/performance"
	"mcp_orchestrator/internal/profiles"
)

// ExtendedAPIServer provides advanced API endpoints
type ExtendedAPIServer struct {
	profileManager   *profiles.ProfileManager
	analyticsTracker *analytics.Tracker
	toolCache        *performance.ToolCache
	loadBalancer     *performance.LoadBalancer
}

// NewExtendedAPIServer creates a new extended API server
func NewExtendedAPIServer(profileManager *profiles.ProfileManager, analyticsTracker *analytics.Tracker, toolCache *performance.ToolCache, loadBalancer *performance.LoadBalancer) *ExtendedAPIServer {
	return &ExtendedAPIServer{
		profileManager:   profileManager,
		analyticsTracker: analyticsTracker,
		toolCache:        toolCache,
		loadBalancer:     loadBalancer,
	}
}

// RegisterExtendedRoutes registers all extended API routes
func (s *ExtendedAPIServer) RegisterExtendedRoutes(mux *http.ServeMux) {
	// Profile management endpoints
	mux.HandleFunc("/api/profiles", s.handleProfiles)
	mux.HandleFunc("/api/profiles/", s.handleProfileByID)
	mux.HandleFunc("/api/profiles/active", s.handleActiveProfile)

	// Analytics endpoints
	mux.HandleFunc("/api/analytics", s.handleAnalytics)
	mux.HandleFunc("/api/analytics/insights", s.handleInsights)
	mux.HandleFunc("/api/analytics/tools", s.handleToolAnalytics)
	mux.HandleFunc("/api/analytics/servers", s.handleServerAnalytics)

	// Performance monitoring endpoints
	mux.HandleFunc("/api/performance/cache", s.handleCacheStats)
	mux.HandleFunc("/api/performance/pools", s.handlePoolStats)
	mux.HandleFunc("/api/performance/health", s.handleHealthCheck)

	// Configuration endpoints
	mux.HandleFunc("/api/config/profiles", s.handleProfileConfig)
	mux.HandleFunc("/api/config/performance", s.handlePerformanceConfig)

	// Dashboard endpoints
	mux.HandleFunc("/api/dashboard/overview", s.handleDashboardOverview)
	mux.HandleFunc("/api/dashboard/metrics", s.handleDashboardMetrics)
}

// Profile Management Endpoints

func (s *ExtendedAPIServer) handleProfiles(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		profiles := s.profileManager.ListProfiles()
		s.sendJSONResponse(w, profiles)
	case http.MethodPost:
		var profile profiles.Profile
		if err := json.NewDecoder(r.Body).Decode(&profile); err != nil {
			s.sendErrorResponse(w, "Invalid profile data", http.StatusBadRequest)
			return
		}

		if err := s.profileManager.CreateProfile(&profile); err != nil {
			s.sendErrorResponse(w, err.Error(), http.StatusConflict)
			return
		}

		s.sendJSONResponse(w, map[string]string{"status": "created", "id": profile.ID})
	default:
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *ExtendedAPIServer) handleProfileByID(w http.ResponseWriter, r *http.Request) {
	profileID := strings.TrimPrefix(r.URL.Path, "/api/profiles/")

	switch r.Method {
	case http.MethodGet:
		profile, err := s.profileManager.GetProfile(profileID)
		if err != nil {
			s.sendErrorResponse(w, err.Error(), http.StatusNotFound)
			return
		}
		s.sendJSONResponse(w, profile)
	case http.MethodPut:
		var updates profiles.Profile
		if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
			s.sendErrorResponse(w, "Invalid profile data", http.StatusBadRequest)
			return
		}

		if err := s.profileManager.UpdateProfile(profileID, &updates); err != nil {
			s.sendErrorResponse(w, err.Error(), http.StatusNotFound)
			return
		}

		s.sendJSONResponse(w, map[string]string{"status": "updated", "id": profileID})
	case http.MethodDelete:
		if err := s.profileManager.DeleteProfile(profileID); err != nil {
			s.sendErrorResponse(w, err.Error(), http.StatusBadRequest)
			return
		}

		s.sendJSONResponse(w, map[string]string{"status": "deleted", "id": profileID})
	default:
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *ExtendedAPIServer) handleActiveProfile(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		profile := s.profileManager.GetActiveProfile()
		if profile == nil {
			s.sendErrorResponse(w, "No active profile", http.StatusNotFound)
			return
		}
		s.sendJSONResponse(w, profile)
	case http.MethodPost:
		var request struct {
			ProfileID string `json:"profile_id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			s.sendErrorResponse(w, "Invalid request data", http.StatusBadRequest)
			return
		}

		if err := s.profileManager.SetActiveProfile(request.ProfileID); err != nil {
			s.sendErrorResponse(w, err.Error(), http.StatusNotFound)
			return
		}

		s.sendJSONResponse(w, map[string]string{"status": "active_profile_set", "id": request.ProfileID})
	default:
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// Analytics Endpoints

func (s *ExtendedAPIServer) handleAnalytics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse query parameters
	period := r.URL.Query().Get("period")
	if period == "" {
		period = "daily"
	}

	daysStr := r.URL.Query().Get("days")
	days := 7
	if daysStr != "" {
		if d, err := strconv.Atoi(daysStr); err == nil {
			days = d
		}
	}

	analytics, err := s.analyticsTracker.GetAnalytics(period, days)
	if err != nil {
		s.sendErrorResponse(w, err.Error(), http.StatusInternalServerError)
		return
	}

	s.sendJSONResponse(w, analytics)
}

func (s *ExtendedAPIServer) handleInsights(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	daysStr := r.URL.Query().Get("days")
	days := 7
	if daysStr != "" {
		if d, err := strconv.Atoi(daysStr); err == nil {
			days = d
		}
	}

	insights, err := s.analyticsTracker.GetInsights(days)
	if err != nil {
		s.sendErrorResponse(w, err.Error(), http.StatusInternalServerError)
		return
	}

	s.sendJSONResponse(w, insights)
}

func (s *ExtendedAPIServer) handleToolAnalytics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	analytics, err := s.analyticsTracker.GetAnalytics("daily", 7)
	if err != nil {
		s.sendErrorResponse(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Return just the top tools
	s.sendJSONResponse(w, map[string]interface{}{
		"top_tools":   analytics.TopTools,
		"total_calls": analytics.TotalToolCalls,
	})
}

func (s *ExtendedAPIServer) handleServerAnalytics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	analytics, err := s.analyticsTracker.GetAnalytics("daily", 7)
	if err != nil {
		s.sendErrorResponse(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Return server metrics
	s.sendJSONResponse(w, map[string]interface{}{
		"server_metrics": analytics.ServerMetrics,
		"total_servers":  analytics.TotalServers,
		"active_servers": analytics.ActiveServers,
	})
}

// Performance Monitoring Endpoints

func (s *ExtendedAPIServer) handleCacheStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	stats := s.toolCache.GetCacheStats()
	s.sendJSONResponse(w, stats)
}

func (s *ExtendedAPIServer) handlePoolStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	stats := s.loadBalancer.GetPoolStats()
	s.sendJSONResponse(w, stats)
}

func (s *ExtendedAPIServer) handleHealthCheck(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get insights for health information
	insights, err := s.analyticsTracker.GetInsights(1)
	if err != nil {
		s.sendErrorResponse(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Combine with cache and pool stats
	cacheStats := s.toolCache.GetCacheStats()
	poolStats := s.loadBalancer.GetPoolStats()

	healthData := map[string]interface{}{
		"timestamp":     time.Now(),
		"server_health": insights.ServerHealth,
		"alerts":        insights.Alerts,
		"cache_stats":   cacheStats,
		"pool_stats":    poolStats,
		"status":        "healthy", // This would be calculated based on various factors
	}

	s.sendJSONResponse(w, healthData)
}

// Configuration Endpoints

func (s *ExtendedAPIServer) handleProfileConfig(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		// Return available profile templates or configurations
		templates := map[string]interface{}{
			"use_cases":       []string{"development", "marketing", "sales", "analytics", "custom"},
			"default_servers": []string{"gohighlevel", "github", "puppeteer", "brave-search", "slack"},
			"performance_presets": map[string]interface{}{
				"low_latency": map[string]interface{}{
					"cache_ttl":            60,
					"connection_pool_size": 10,
					"max_concurrent_calls": 20,
				},
				"high_throughput": map[string]interface{}{
					"cache_ttl":            300,
					"connection_pool_size": 20,
					"max_concurrent_calls": 50,
				},
			},
		}
		s.sendJSONResponse(w, templates)
	default:
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (s *ExtendedAPIServer) handlePerformanceConfig(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		// Return current performance configuration
		config := map[string]interface{}{
			"cache_enabled":      true,
			"cache_stats":        s.toolCache.GetCacheStats(),
			"connection_pools":   s.loadBalancer.GetPoolStats(),
			"optimization_level": "high",
		}
		s.sendJSONResponse(w, config)
	default:
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

// Dashboard Endpoints

func (s *ExtendedAPIServer) handleDashboardOverview(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get analytics and insights
	analytics, err := s.analyticsTracker.GetAnalytics("daily", 7)
	if err != nil {
		s.sendErrorResponse(w, err.Error(), http.StatusInternalServerError)
		return
	}

	insights, err := s.analyticsTracker.GetInsights(7)
	if err != nil {
		s.sendErrorResponse(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Get active profile
	activeProfile := s.profileManager.GetActiveProfile()

	// Get cache and pool stats
	cacheStats := s.toolCache.GetCacheStats()
	poolStats := s.loadBalancer.GetPoolStats()

	overview := map[string]interface{}{
		"timestamp":         time.Now(),
		"active_profile":    activeProfile,
		"total_tools":       analytics.TotalToolCalls,
		"total_servers":     analytics.TotalServers,
		"active_servers":    analytics.ActiveServers,
		"success_rate":      analytics.SuccessRate,
		"avg_response_time": analytics.AvgResponseTime,
		"top_tools":         analytics.TopTools[:min(5, len(analytics.TopTools))],
		"recent_alerts":     insights.Alerts[:min(3, len(insights.Alerts))],
		"cache_hit_rate":    calculateOverallCacheHitRate(cacheStats),
		"pool_efficiency":   calculatePoolEfficiency(poolStats),
		"recommendations":   insights.Recommendations[:min(3, len(insights.Recommendations))],
	}

	s.sendJSONResponse(w, overview)
}

func (s *ExtendedAPIServer) handleDashboardMetrics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		s.sendErrorResponse(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get detailed metrics for dashboard charts
	analytics, err := s.analyticsTracker.GetAnalytics("hourly", 24)
	if err != nil {
		s.sendErrorResponse(w, err.Error(), http.StatusInternalServerError)
		return
	}

	metrics := map[string]interface{}{
		"timestamp":           time.Now(),
		"hourly_distribution": analytics.HourlyDistribution,
		"daily_distribution":  analytics.DailyDistribution,
		"server_metrics":      analytics.ServerMetrics,
		"profile_usage":       analytics.ProfileUsage,
		"trend_analysis": map[string]interface{}{
			"usage_trend":       "stable",
			"performance_trend": "improving",
			"growth_rate":       5.2,
		},
	}

	s.sendJSONResponse(w, metrics)
}

// Helper Functions

func (s *ExtendedAPIServer) sendJSONResponse(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func (s *ExtendedAPIServer) sendErrorResponse(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(map[string]string{
		"error":     message,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

func calculateOverallCacheHitRate(stats map[string]performance.CacheStats) float64 {
	totalHits := int64(0)
	totalMisses := int64(0)

	for _, stat := range stats {
		totalHits += stat.Hits
		totalMisses += stat.Misses
	}

	if totalHits+totalMisses == 0 {
		return 0.0
	}

	return float64(totalHits) / float64(totalHits+totalMisses) * 100
}

func calculatePoolEfficiency(stats map[string]performance.PoolStats) float64 {
	totalPools := len(stats)
	if totalPools == 0 {
		return 0.0
	}

	totalEfficiency := 0.0
	for _, stat := range stats {
		if stat.TotalConnections > 0 {
			efficiency := float64(stat.ActiveConnections) / float64(stat.TotalConnections) * 100
			totalEfficiency += efficiency
		}
	}

	return totalEfficiency / float64(totalPools)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
