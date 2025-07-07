package profiles

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Profile represents a configuration profile for different use cases
type Profile struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	UseCase     string    `json:"use_case"` // "development", "marketing", "sales", "analytics", "custom"
	Active      bool      `json:"active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`

	// Server configuration
	EnabledServers []string                `json:"enabled_servers"`
	ServerConfigs  map[string]ServerConfig `json:"server_configs"`

	// Tool filtering and preferences
	ToolFilters ToolFilters `json:"tool_filters"`
	ToolLimits  ToolLimits  `json:"tool_limits"`

	// Performance settings
	Performance PerformanceConfig `json:"performance"`

	// Analytics settings
	Analytics AnalyticsConfig `json:"analytics"`
}

// ServerConfig holds server-specific configuration for a profile
type ServerConfig struct {
	Enabled    bool              `json:"enabled"`
	Priority   int               `json:"priority"`   // Lower number = higher priority
	MaxTools   int               `json:"max_tools"`  // Limit tools from this server
	Categories []string          `json:"categories"` // Allowed categories
	EnvVars    map[string]string `json:"env_vars"`   // Environment variables
}

// ToolFilters defines which tools are included/excluded
type ToolFilters struct {
	IncludeCategories []string `json:"include_categories"`
	ExcludeCategories []string `json:"exclude_categories"`
	IncludeTools      []string `json:"include_tools"`
	ExcludeTools      []string `json:"exclude_tools"`
	RequiredKeywords  []string `json:"required_keywords"`
}

// ToolLimits defines limits for tool usage
type ToolLimits struct {
	MaxToolsPerServer  int `json:"max_tools_per_server"`
	MaxToolsTotal      int `json:"max_tools_total"`
	MaxConcurrentCalls int `json:"max_concurrent_calls"`
	RateLimitPerMinute int `json:"rate_limit_per_minute"`
}

// PerformanceConfig defines performance settings
type PerformanceConfig struct {
	EnableCaching      bool `json:"enable_caching"`
	CacheTTLSeconds    int  `json:"cache_ttl_seconds"`
	ConnectionPoolSize int  `json:"connection_pool_size"`
	RequestTimeoutMs   int  `json:"request_timeout_ms"`
	EnableCompression  bool `json:"enable_compression"`
}

// AnalyticsConfig defines analytics settings
type AnalyticsConfig struct {
	TrackToolUsage   bool `json:"track_tool_usage"`
	TrackPerformance bool `json:"track_performance"`
	RetentionDays    int  `json:"retention_days"`
	ExportMetrics    bool `json:"export_metrics"`
}

// ProfileManager manages orchestrator profiles
type ProfileManager struct {
	profiles  map[string]*Profile
	activeID  string
	configDir string
	mu        sync.RWMutex
}

// NewProfileManager creates a new profile manager
func NewProfileManager(configDir string) *ProfileManager {
	manager := &ProfileManager{
		profiles:  make(map[string]*Profile),
		configDir: configDir,
	}

	// Create config directory if it doesn't exist
	os.MkdirAll(filepath.Join(configDir, "profiles"), 0755)

	// Load existing profiles
	manager.loadProfiles()

	// Create default profiles if none exist
	if len(manager.profiles) == 0 {
		manager.createDefaultProfiles()
	}

	return manager
}

// createDefaultProfiles creates predefined profiles for common use cases
func (pm *ProfileManager) createDefaultProfiles() {
	// Development Profile
	devProfile := &Profile{
		ID:             "development",
		Name:           "Development",
		Description:    "Optimized for software development workflows",
		UseCase:        "development",
		Active:         true,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
		EnabledServers: []string{"github", "puppeteer", "brave-search"},
		ServerConfigs: map[string]ServerConfig{
			"github": {
				Enabled:    true,
				Priority:   1,
				MaxTools:   50,
				Categories: []string{"development", "version_control"},
			},
			"puppeteer": {
				Enabled:    true,
				Priority:   2,
				MaxTools:   10,
				Categories: []string{"web_browser", "automation"},
			},
			"brave-search": {
				Enabled:    true,
				Priority:   3,
				MaxTools:   5,
				Categories: []string{"web_browser", "search"},
			},
		},
		ToolFilters: ToolFilters{
			IncludeCategories: []string{"development", "web_browser"},
		},
		ToolLimits: ToolLimits{
			MaxToolsPerServer:  50,
			MaxToolsTotal:      100,
			MaxConcurrentCalls: 10,
			RateLimitPerMinute: 100,
		},
		Performance: PerformanceConfig{
			EnableCaching:      true,
			CacheTTLSeconds:    300,
			ConnectionPoolSize: 5,
			RequestTimeoutMs:   30000,
			EnableCompression:  true,
		},
		Analytics: AnalyticsConfig{
			TrackToolUsage:   true,
			TrackPerformance: true,
			RetentionDays:    30,
			ExportMetrics:    true,
		},
	}

	// Marketing Profile
	marketingProfile := &Profile{
		ID:             "marketing",
		Name:           "Marketing & CRM",
		Description:    "Optimized for marketing automation and customer management",
		UseCase:        "marketing",
		Active:         false,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
		EnabledServers: []string{"gohighlevel", "slack", "brave-search"},
		ServerConfigs: map[string]ServerConfig{
			"gohighlevel": {
				Enabled:    true,
				Priority:   1,
				MaxTools:   300,
				Categories: []string{"gohighlevel", "crm", "marketing"},
			},
			"slack": {
				Enabled:    true,
				Priority:   2,
				MaxTools:   15,
				Categories: []string{"communication"},
			},
			"brave-search": {
				Enabled:    true,
				Priority:   3,
				MaxTools:   5,
				Categories: []string{"web_browser", "search"},
			},
		},
		ToolFilters: ToolFilters{
			IncludeCategories: []string{"gohighlevel", "communication", "marketing"},
		},
		ToolLimits: ToolLimits{
			MaxToolsPerServer:  300,
			MaxToolsTotal:      350,
			MaxConcurrentCalls: 20,
			RateLimitPerMinute: 200,
		},
		Performance: PerformanceConfig{
			EnableCaching:      true,
			CacheTTLSeconds:    600,
			ConnectionPoolSize: 10,
			RequestTimeoutMs:   45000,
			EnableCompression:  true,
		},
		Analytics: AnalyticsConfig{
			TrackToolUsage:   true,
			TrackPerformance: true,
			RetentionDays:    90,
			ExportMetrics:    true,
		},
	}

	// All Tools Profile
	allProfile := &Profile{
		ID:             "all_tools",
		Name:           "All Tools",
		Description:    "Access to all available tools and servers",
		UseCase:        "custom",
		Active:         false,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
		EnabledServers: []string{"gohighlevel", "github", "puppeteer", "brave-search", "slack", "google-maps"},
		ServerConfigs: map[string]ServerConfig{
			"gohighlevel":  {Enabled: true, Priority: 1, MaxTools: 300},
			"github":       {Enabled: true, Priority: 2, MaxTools: 50},
			"puppeteer":    {Enabled: true, Priority: 3, MaxTools: 10},
			"brave-search": {Enabled: true, Priority: 4, MaxTools: 5},
			"slack":        {Enabled: true, Priority: 5, MaxTools: 15},
			"google-maps":  {Enabled: true, Priority: 6, MaxTools: 10},
		},
		ToolLimits: ToolLimits{
			MaxToolsPerServer:  300,
			MaxToolsTotal:      500,
			MaxConcurrentCalls: 30,
			RateLimitPerMinute: 300,
		},
		Performance: PerformanceConfig{
			EnableCaching:      true,
			CacheTTLSeconds:    300,
			ConnectionPoolSize: 15,
			RequestTimeoutMs:   60000,
			EnableCompression:  true,
		},
		Analytics: AnalyticsConfig{
			TrackToolUsage:   true,
			TrackPerformance: true,
			RetentionDays:    30,
			ExportMetrics:    true,
		},
	}

	// Save default profiles
	pm.profiles["development"] = devProfile
	pm.profiles["marketing"] = marketingProfile
	pm.profiles["all_tools"] = allProfile
	pm.activeID = "development"

	pm.saveProfiles()
}

// GetActiveProfile returns the currently active profile
func (pm *ProfileManager) GetActiveProfile() *Profile {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	if profile, exists := pm.profiles[pm.activeID]; exists {
		return profile
	}

	// Return first profile as fallback
	for _, profile := range pm.profiles {
		return profile
	}

	return nil
}

// GetProfile returns a profile by ID
func (pm *ProfileManager) GetProfile(id string) (*Profile, error) {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	if profile, exists := pm.profiles[id]; exists {
		return profile, nil
	}

	return nil, fmt.Errorf("profile %s not found", id)
}

// ListProfiles returns all profiles
func (pm *ProfileManager) ListProfiles() []*Profile {
	pm.mu.RLock()
	defer pm.mu.RUnlock()

	profiles := make([]*Profile, 0, len(pm.profiles))
	for _, profile := range pm.profiles {
		profiles = append(profiles, profile)
	}

	return profiles
}

// SetActiveProfile sets the active profile
func (pm *ProfileManager) SetActiveProfile(id string) error {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	if _, exists := pm.profiles[id]; !exists {
		return fmt.Errorf("profile %s not found", id)
	}

	// Update active status
	for pid, profile := range pm.profiles {
		profile.Active = (pid == id)
	}

	pm.activeID = id
	pm.saveProfiles()

	return nil
}

// CreateProfile creates a new profile
func (pm *ProfileManager) CreateProfile(profile *Profile) error {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	if _, exists := pm.profiles[profile.ID]; exists {
		return fmt.Errorf("profile %s already exists", profile.ID)
	}

	profile.CreatedAt = time.Now()
	profile.UpdatedAt = time.Now()

	pm.profiles[profile.ID] = profile
	pm.saveProfiles()

	return nil
}

// UpdateProfile updates an existing profile
func (pm *ProfileManager) UpdateProfile(id string, updates *Profile) error {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	profile, exists := pm.profiles[id]
	if !exists {
		return fmt.Errorf("profile %s not found", id)
	}

	// Update fields
	if updates.Name != "" {
		profile.Name = updates.Name
	}
	if updates.Description != "" {
		profile.Description = updates.Description
	}
	if len(updates.EnabledServers) > 0 {
		profile.EnabledServers = updates.EnabledServers
	}
	if len(updates.ServerConfigs) > 0 {
		profile.ServerConfigs = updates.ServerConfigs
	}

	profile.UpdatedAt = time.Now()

	pm.saveProfiles()
	return nil
}

// DeleteProfile deletes a profile
func (pm *ProfileManager) DeleteProfile(id string) error {
	pm.mu.Lock()
	defer pm.mu.Unlock()

	if _, exists := pm.profiles[id]; !exists {
		return fmt.Errorf("profile %s not found", id)
	}

	// Don't delete if it's the active profile and only profile
	if pm.activeID == id && len(pm.profiles) == 1 {
		return fmt.Errorf("cannot delete the only profile")
	}

	delete(pm.profiles, id)

	// Set new active profile if needed
	if pm.activeID == id {
		for pid := range pm.profiles {
			pm.activeID = pid
			pm.profiles[pid].Active = true
			break
		}
	}

	pm.saveProfiles()
	return nil
}

// saveProfiles saves profiles to disk
func (pm *ProfileManager) saveProfiles() {
	for id, profile := range pm.profiles {
		data, err := json.MarshalIndent(profile, "", "  ")
		if err != nil {
			continue
		}

		filename := filepath.Join(pm.configDir, "profiles", fmt.Sprintf("%s.json", id))
		os.WriteFile(filename, data, 0644)
	}

	// Save active profile info
	activeData := map[string]string{"active_profile": pm.activeID}
	data, _ := json.MarshalIndent(activeData, "", "  ")
	activeFile := filepath.Join(pm.configDir, "profiles", "active.json")
	os.WriteFile(activeFile, data, 0644)
}

// loadProfiles loads profiles from disk
func (pm *ProfileManager) loadProfiles() {
	profilesDir := filepath.Join(pm.configDir, "profiles")

	// Load active profile info
	activeFile := filepath.Join(profilesDir, "active.json")
	if data, err := os.ReadFile(activeFile); err == nil {
		var activeData map[string]string
		if json.Unmarshal(data, &activeData) == nil {
			pm.activeID = activeData["active_profile"]
		}
	}

	// Load all profile files
	entries, err := os.ReadDir(profilesDir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		if !entry.IsDir() && filepath.Ext(entry.Name()) == ".json" && entry.Name() != "active.json" {
			filename := filepath.Join(profilesDir, entry.Name())
			data, err := os.ReadFile(filename)
			if err != nil {
				continue
			}

			var profile Profile
			if err := json.Unmarshal(data, &profile); err != nil {
				continue
			}

			pm.profiles[profile.ID] = &profile
		}
	}
}
