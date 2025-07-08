package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"mcp_orchestrator/internal/mcp"
	"mcp_orchestrator/internal/servers"
	"mcp_orchestrator/internal/ui"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	// Initialize the MCP orchestrator
	orchestrator := mcp.NewOrchestrator()

	// Initialize the server manager
	serverManager := servers.NewManager(orchestrator)

	// Initialize UI API
	uiAPI := ui.NewAPI(serverManager)

	// Start the MCP server (for Claude Desktop)
	go func() {
		log.Println("Starting MCP server on :3000")
		if err := orchestrator.Start(":3000"); err != nil {
			log.Fatal("Failed to start MCP server:", err)
		}
	}()

	// Start the UI API server
	go func() {
		r := gin.Default()

		// Enable CORS for local development
		config := cors.DefaultConfig()
		config.AllowOrigins = []string{"http://localhost:3001"}
		config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
		config.AllowHeaders = []string{"Origin", "Content-Type", "Authorization"}
		r.Use(cors.New(config))

		// API routes
		api := r.Group("/api")
		{
			api.GET("/servers", uiAPI.ListServers)
			api.GET("/categories", uiAPI.GetCategories)
			api.POST("/servers/install", uiAPI.InstallServer)
			api.POST("/servers/:id/start", uiAPI.StartServer)
			api.POST("/servers/:id/stop", uiAPI.StopServer)
			api.GET("/servers/:id/status", uiAPI.GetServerStatus)
			api.GET("/servers/:id/logs", uiAPI.GetServerLogs)
			api.GET("/servers/:id/credentials", uiAPI.GetServerRequiredCredentials)

			// Validation and diagnostics endpoints
			api.GET("/validation/servers", uiAPI.ValidateServers)
			api.GET("/validation/servers/:id", uiAPI.ValidateServer)
			api.POST("/validation/servers/:id/autofix", uiAPI.AutoFixServer)
			api.GET("/diagnostics/tools", uiAPI.GetToolDiagnostics)
			api.GET("/system/health", uiAPI.GetSystemHealth)

			// Enhanced error reporting endpoints
			api.GET("/errors/servers", uiAPI.GetAllServerErrors)
			api.GET("/errors/servers/:id", uiAPI.GetServerErrors)
			api.DELETE("/errors/servers/:id", uiAPI.ClearServerErrors)
			api.GET("/servers/:id/details", uiAPI.GetServerDetails)
		}

		// Health check
		r.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{"status": "ok"})
		})

		log.Println("Starting UI API server on :8080")
		if err := r.Run(":8080"); err != nil {
			log.Fatal("Failed to start UI API server:", err)
		}
	}()

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	<-sigChan
	log.Println("Shutting down MCP orchestrator...")

	// Graceful shutdown
	serverManager.StopAll()
	orchestrator.Stop()
}
