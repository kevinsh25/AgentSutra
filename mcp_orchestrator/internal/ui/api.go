package ui

import (
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"mcp_orchestrator/internal/servers"

	"github.com/gin-gonic/gin"
)

// API handles HTTP requests for the UI
type API struct {
	serverManager *servers.Manager
}

// NewAPI creates a new UI API instance
func NewAPI(serverManager *servers.Manager) *API {
	return &API{
		serverManager: serverManager,
	}
}

// InstallRequest represents a server installation request
type InstallRequest struct {
	ServerID string            `json:"server_id"`
	Config   map[string]string `json:"config"`
}

// ListServers returns all available and configured servers
func (a *API) ListServers(c *gin.Context) {
	// Get available servers (templates)
	available := a.serverManager.GetAvailableServers()

	// Get configured servers
	configured := a.serverManager.ListServers()

	// Create a map of configured servers by ID
	configuredMap := make(map[string]*servers.ServerConfig)
	for _, server := range configured {
		configuredMap[server.ID] = server
	}

	// Merge available and configured servers
	result := make([]*servers.ServerConfig, 0, len(available))
	for _, server := range available {
		if configured, exists := configuredMap[server.ID]; exists {
			// Use the configured version
			result = append(result, configured)
		} else {
			// Use the template version
			result = append(result, server)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"servers": result,
	})
}

// InstallServer handles server installation requests
func (a *API) InstallServer(c *gin.Context) {
	var req InstallRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request format",
		})
		return
	}

	// Validate required credentials for servers that need them
	switch req.ServerID {
	case "gohighlevel":
		if req.Config["GHL_API_KEY"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "GHL_API_KEY is required for GoHighLevel MCP",
			})
			return
		}
		if req.Config["GHL_LOCATION_ID"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "GHL_LOCATION_ID is required for GoHighLevel MCP",
			})
			return
		}
		// Set default values
		if req.Config["GHL_BASE_URL"] == "" {
			req.Config["GHL_BASE_URL"] = "https://services.leadconnectorhq.com"
		}
		if req.Config["NODE_ENV"] == "" {
			req.Config["NODE_ENV"] = "production"
		}
		if req.Config["PORT"] == "" {
			req.Config["PORT"] = "8000"
		}
	case "meta-ads":
		if req.Config["META_ACCESS_TOKEN"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "META_ACCESS_TOKEN is required for Meta Ads MCP",
			})
			return
		}
		if req.Config["META_APP_ID"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "META_APP_ID is required for Meta Ads MCP",
			})
			return
		}
		if req.Config["META_APP_SECRET"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "META_APP_SECRET is required for Meta Ads MCP",
			})
			return
		}
	case "google-ads":
		if req.Config["GOOGLE_ADS_CUSTOMER_ID"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "GOOGLE_ADS_CUSTOMER_ID is required for Google Ads MCP",
			})
			return
		}
		if req.Config["GOOGLE_ADS_DEVELOPER_TOKEN"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "GOOGLE_ADS_DEVELOPER_TOKEN is required for Google Ads MCP",
			})
			return
		}
	case "github":
		if req.Config["GITHUB_PERSONAL_ACCESS_TOKEN"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "GITHUB_PERSONAL_ACCESS_TOKEN is required for GitHub MCP",
			})
			return
		}
	case "slack":
		if req.Config["SLACK_BOT_TOKEN"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "SLACK_BOT_TOKEN is required for Slack MCP",
			})
			return
		}
	case "notion":
		if req.Config["NOTION_API_KEY"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "NOTION_API_KEY is required for Notion MCP",
			})
			return
		}
	case "stripe":
		if req.Config["STRIPE_SECRET_KEY"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "STRIPE_SECRET_KEY is required for Stripe MCP",
			})
			return
		}
	case "google-maps":
		if req.Config["GOOGLE_MAPS_API_KEY"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "GOOGLE_MAPS_API_KEY is required for Google Maps MCP",
			})
			return
		}
	case "gmail":
		if req.Config["GMAIL_CREDENTIALS"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "GMAIL_CREDENTIALS is required for Gmail MCP",
			})
			return
		}
	case "figma":
		if req.Config["FIGMA_ACCESS_TOKEN"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "FIGMA_ACCESS_TOKEN is required for Figma MCP",
			})
			return
		}
	case "brave-search":
		if req.Config["BRAVE_SEARCH_API_KEY"] == "" {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "BRAVE_SEARCH_API_KEY is required for Brave Search MCP",
			})
			return
		}
	case "puppeteer", "docker":
		// These servers don't require API keys
		break
	default:
		// For unknown servers, allow installation without credentials
		break
	}

	// Start installation
	if err := a.serverManager.InstallServer(req.ServerID, req.Config); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Installation started",
	})
}

// StartServer starts a specific server
func (a *API) StartServer(c *gin.Context) {
	serverID := c.Param("id")

	if err := a.serverManager.StartServer(serverID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Server started",
	})
}

// StopServer stops a specific server
func (a *API) StopServer(c *gin.Context) {
	serverID := c.Param("id")

	if err := a.serverManager.StopServer(serverID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Server stopped",
	})
}

// GetServerStatus returns the status of a specific server
func (a *API) GetServerStatus(c *gin.Context) {
	serverID := c.Param("id")

	server, err := a.serverManager.GetServer(serverID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": server.Status,
		"port":   server.Port,
	})
}

// GetServerLogs returns logs for a specific server
func (a *API) GetServerLogs(c *gin.Context) {
	serverID := c.Param("id")

	server, err := a.serverManager.GetServer(serverID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Get optional limit parameter
	limit := 100
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil {
			limit = parsedLimit
		}
	}

	logs := server.Logs
	if len(logs) > limit {
		logs = logs[len(logs)-limit:]
	}

	c.JSON(http.StatusOK, gin.H{
		"logs": logs,
	})
}

// CategoryInfo represents server category information
type CategoryInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Icon        string `json:"icon"`
	ServerCount int    `json:"server_count"`
	ToolsCount  int    `json:"tools_count"`
}

// GetCategories returns all available server categories with metadata
func (a *API) GetCategories(c *gin.Context) {
	servers := a.serverManager.GetAvailableServers()

	// Count servers and tools by category
	categoryMap := make(map[string]*CategoryInfo)

	// Initialize predefined categories
	categories := []*CategoryInfo{
		{"design", "Design & Prototyping", "Design collaboration and prototyping tools", "🎨", 0, 0},
		{"development", "Development & Version Control", "Code repositories and development tools", "💻", 0, 0},
		{"communication", "Communication & Collaboration", "Team messaging and collaboration platforms", "💬", 0, 0},
		{"productivity", "Productivity & Project Management", "Note-taking and project management tools", "📝", 0, 0},
		{"ecommerce", "E-commerce & Payments", "Online stores and payment processing", "🛒", 0, 0},
		{"advertising", "Advertising & Marketing", "Ad platforms and marketing automation", "📢", 0, 0},
		{"crm", "CRM & Sales", "Customer relationship management", "👥", 0, 0},
		{"maps", "Maps & Location", "Mapping and location services", "🗺️", 0, 0},
		{"web_browser", "Web & Browser", "Web search and browser automation", "🌐", 0, 0},
		{"email", "Email & Communication", "Email services and communication tools", "📧", 0, 0},
		{"cloud", "Cloud & Infrastructure", "Cloud services and infrastructure management", "☁️", 0, 0},
		{"financial", "Financial Services", "Banking and financial data services", "💰", 0, 0},
		{"analytics", "Analytics & Data", "Data analysis and business intelligence", "📊", 0, 0},
	}

	for _, cat := range categories {
		categoryMap[cat.ID] = cat
	}

	// Count servers and tools for each category
	for _, server := range servers {
		if cat, exists := categoryMap[server.Category]; exists {
			cat.ServerCount++
			cat.ToolsCount += server.ToolsCount
		}
	}

	// Filter out categories with no servers
	result := make([]*CategoryInfo, 0)
	for _, cat := range categories {
		if cat.ServerCount > 0 {
			result = append(result, cat)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"categories": result,
	})
}

// ValidateServers validates all server configurations
func (a *API) ValidateServers(c *gin.Context) {
	// Create config validator
	homeDir, _ := os.UserHomeDir()
	basePath := filepath.Join(homeDir, ".mcp_orchestrator")
	validator := servers.NewConfigValidator(basePath)

	// Get all servers
	allServers := a.serverManager.ListServers()

	// Convert to map for validation
	serverMap := make(map[string]*servers.ServerConfig)
	for _, server := range allServers {
		serverMap[server.ID] = server
	}

	// Validate all servers
	results := validator.ValidateAllServers(serverMap)

	c.JSON(http.StatusOK, gin.H{
		"validation_results": results,
		"timestamp":          time.Now().Unix(),
	})
}

// ValidateServer validates a specific server configuration
func (a *API) ValidateServer(c *gin.Context) {
	serverID := c.Param("id")

	server, err := a.serverManager.GetServer(serverID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Create config validator
	homeDir, _ := os.UserHomeDir()
	basePath := filepath.Join(homeDir, ".mcp_orchestrator")
	validator := servers.NewConfigValidator(basePath)

	// Validate the server
	result := validator.ValidateServer(serverID, server)

	c.JSON(http.StatusOK, gin.H{
		"validation_result": result,
		"timestamp":         time.Now().Unix(),
	})
}

// AutoFixServer attempts to automatically fix server configuration issues
func (a *API) AutoFixServer(c *gin.Context) {
	serverID := c.Param("id")

	server, err := a.serverManager.GetServer(serverID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Create config validator
	homeDir, _ := os.UserHomeDir()
	basePath := filepath.Join(homeDir, ".mcp_orchestrator")
	validator := servers.NewConfigValidator(basePath)

	// Validate the server first
	result := validator.ValidateServer(serverID, server)

	// Attempt auto-fix
	if !result.IsValid {
		if err := validator.AutoFixIssues(result); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":   "Failed to auto-fix issues",
				"details": err.Error(),
			})
			return
		}

		// Re-validate after fixes
		result = validator.ValidateServer(serverID, server)
	}

	c.JSON(http.StatusOK, gin.H{
		"message":           "Auto-fix completed",
		"validation_result": result,
		"timestamp":         time.Now().Unix(),
	})
}

// GetToolDiagnostics gets tool discovery diagnostics
func (a *API) GetToolDiagnostics(c *gin.Context) {
	// This would typically be called by the enhanced discovery system
	// For now, return a placeholder response
	c.JSON(http.StatusOK, gin.H{
		"diagnostics": []map[string]interface{}{},
		"timestamp":   time.Now().Unix(),
		"message":     "Tool diagnostics available via enhanced discovery system",
	})
}

// GetSystemHealth returns overall system health status
func (a *API) GetSystemHealth(c *gin.Context) {
	// Get all servers
	allServers := a.serverManager.ListServers()

	// Count servers by status
	statusCounts := make(map[string]int)
	var totalServers, runningServers, errorServers int

	for _, server := range allServers {
		statusCounts[server.Status]++
		totalServers++

		if server.Status == "running" {
			runningServers++
		} else if server.Status == "failed" || server.Status == "error" {
			errorServers++
		}
	}

	// Calculate health score (0-100)
	healthScore := 100
	if totalServers > 0 {
		healthScore = (runningServers * 100) / totalServers
	}

	// Determine overall status
	overallStatus := "healthy"
	if errorServers > 0 {
		overallStatus = "degraded"
	}
	if runningServers == 0 && totalServers > 0 {
		overallStatus = "unhealthy"
	}

	c.JSON(http.StatusOK, gin.H{
		"health": map[string]interface{}{
			"status":           overallStatus,
			"score":            healthScore,
			"total_servers":    totalServers,
			"running_servers":  runningServers,
			"error_servers":    errorServers,
			"status_breakdown": statusCounts,
			"timestamp":        time.Now().Unix(),
		},
	})
}

// GetServerErrors returns enhanced error information for a server
func (a *API) GetServerErrors(c *gin.Context) {
	serverID := c.Param("id")

	errors := a.serverManager.GetErrors(serverID)

	c.JSON(http.StatusOK, gin.H{
		"server_id": serverID,
		"errors":    errors,
		"count":     len(errors),
		"timestamp": time.Now().Unix(),
	})
}

// GetAllServerErrors returns enhanced error information for all servers
func (a *API) GetAllServerErrors(c *gin.Context) {
	allErrors := a.serverManager.GetAllErrors()

	totalErrors := 0
	for _, errors := range allErrors {
		totalErrors += len(errors)
	}

	c.JSON(http.StatusOK, gin.H{
		"errors":      allErrors,
		"total_count": totalErrors,
		"timestamp":   time.Now().Unix(),
	})
}

// ClearServerErrors clears error history for a server
func (a *API) ClearServerErrors(c *gin.Context) {
	serverID := c.Param("id")

	a.serverManager.ClearErrors(serverID)

	c.JSON(http.StatusOK, gin.H{
		"message":   "Errors cleared successfully",
		"server_id": serverID,
		"timestamp": time.Now().Unix(),
	})
}

// GetServerDetails returns comprehensive server information including errors
func (a *API) GetServerDetails(c *gin.Context) {
	serverID := c.Param("id")

	server, err := a.serverManager.GetServer(serverID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": err.Error(),
		})
		return
	}

	// Get errors for this server
	errors := a.serverManager.GetErrors(serverID)

	// Get validation result
	homeDir, _ := os.UserHomeDir()
	basePath := filepath.Join(homeDir, ".mcp_orchestrator")
	validator := servers.NewConfigValidator(basePath)
	validationResult := validator.ValidateServer(serverID, server)

	c.JSON(http.StatusOK, gin.H{
		"server":            server,
		"errors":            errors,
		"error_count":       len(errors),
		"validation_result": validationResult,
		"timestamp":         time.Now().Unix(),
	})
}

// GetRequiredCredentials returns the required credentials for a server
func (a *API) GetRequiredCredentials(serverID string) []string {
	switch serverID {
	case "gohighlevel":
		return []string{"GHL_API_KEY", "GHL_LOCATION_ID"}
	case "meta-ads":
		return []string{"META_ACCESS_TOKEN", "META_APP_ID", "META_APP_SECRET"}
	case "google-ads":
		return []string{"GOOGLE_ADS_CUSTOMER_ID", "GOOGLE_ADS_DEVELOPER_TOKEN"}
	case "github":
		return []string{"GITHUB_PERSONAL_ACCESS_TOKEN"}
	case "slack":
		return []string{"SLACK_BOT_TOKEN"}
	case "notion":
		return []string{"NOTION_API_KEY"}
	case "stripe":
		return []string{"STRIPE_SECRET_KEY"}
	case "google-maps":
		return []string{"GOOGLE_MAPS_API_KEY"}
	case "gmail":
		return []string{"GMAIL_CREDENTIALS"}
	case "figma":
		return []string{"FIGMA_ACCESS_TOKEN"}
	case "brave-search":
		return []string{"BRAVE_SEARCH_API_KEY"}
	case "puppeteer", "docker":
		return []string{} // No credentials required
	default:
		return []string{} // Unknown servers don't require credentials
	}
}

// GetServerRequiredCredentials returns the required credentials for a specific server
func (a *API) GetServerRequiredCredentials(c *gin.Context) {
	serverID := c.Param("id")

	credentials := a.GetRequiredCredentials(serverID)

	c.JSON(http.StatusOK, gin.H{
		"server_id":            serverID,
		"required_credentials": credentials,
		"requires_credentials": len(credentials) > 0,
	})
}
