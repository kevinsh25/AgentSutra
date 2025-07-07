package mcp

import (
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
)

// MCPMessage represents a generic MCP message
type MCPMessage struct {
	ID      interface{} `json:"id,omitempty"`
	Method  string      `json:"method,omitempty"`
	Params  interface{} `json:"params,omitempty"`
	Result  interface{} `json:"result,omitempty"`
	Error   interface{} `json:"error,omitempty"`
	JSONRPC string      `json:"jsonrpc"`
}

// Orchestrator manages multiple MCP servers and acts as a proxy
type Orchestrator struct {
	servers  map[string]*MCPServer
	mu       sync.RWMutex
	upgrader websocket.Upgrader
}

// MCPServer represents a managed MCP server
type MCPServer struct {
	ID     string
	Name   string
	Status string
	Port   int
	conn   *websocket.Conn
}

// NewOrchestrator creates a new MCP orchestrator
func NewOrchestrator() *Orchestrator {
	return &Orchestrator{
		servers: make(map[string]*MCPServer),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true // Allow all origins for local development
			},
		},
	}
}

// Start starts the MCP orchestrator server
func (o *Orchestrator) Start(addr string) error {
	http.HandleFunc("/", o.handleWebSocket)
	log.Printf("MCP orchestrator listening on %s", addr)
	return http.ListenAndServe(addr, nil)
}

// Stop stops the orchestrator
func (o *Orchestrator) Stop() {
	o.mu.Lock()
	defer o.mu.Unlock()

	for _, server := range o.servers {
		if server.conn != nil {
			server.conn.Close()
		}
	}
}

// handleWebSocket handles WebSocket connections from Claude Desktop
func (o *Orchestrator) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := o.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}
	defer conn.Close()

	log.Println("Claude Desktop connected to MCP orchestrator")

	for {
		var msg MCPMessage
		if err := conn.ReadJSON(&msg); err != nil {
			log.Printf("Error reading message: %v", err)
			break
		}

		log.Printf("Received message: %+v", msg)

		// Route the message to appropriate server or handle internally
		response := o.routeMessage(msg)

		if err := conn.WriteJSON(response); err != nil {
			log.Printf("Error writing response: %v", err)
			break
		}
	}
}

// routeMessage routes messages to appropriate MCP servers
func (o *Orchestrator) routeMessage(msg MCPMessage) MCPMessage {
	// Handle orchestrator-specific methods
	switch msg.Method {
	case "initialize":
		return o.handleInitialize(msg)
	case "tools/list":
		return o.handleToolsList(msg)
	default:
		// Route to appropriate server based on tool name or context
		return o.routeToServer(msg)
	}
}

// handleInitialize handles the MCP initialize request
func (o *Orchestrator) handleInitialize(msg MCPMessage) MCPMessage {
	return MCPMessage{
		ID:      msg.ID,
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"protocolVersion": "2024-11-05",
			"capabilities": map[string]interface{}{
				"tools": map[string]interface{}{},
			},
			"serverInfo": map[string]interface{}{
				"name":    "MCP Orchestrator",
				"version": "1.0.0",
			},
		},
	}
}

// handleToolsList aggregates tools from all connected servers
func (o *Orchestrator) handleToolsList(msg MCPMessage) MCPMessage {
	o.mu.RLock()
	defer o.mu.RUnlock()

	var allTools []interface{}

	// Add tools from all connected servers
	for _, server := range o.servers {
		if server.Status == "running" {
			// For now, add placeholder tools
			// In a real implementation, we'd query each server for its tools
			allTools = append(allTools, map[string]interface{}{
				"name":        fmt.Sprintf("%s_tool", server.Name),
				"description": fmt.Sprintf("Tool from %s server", server.Name),
				"inputSchema": map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"query": map[string]interface{}{
							"type":        "string",
							"description": "Query parameter",
						},
					},
				},
			})
		}
	}

	return MCPMessage{
		ID:      msg.ID,
		JSONRPC: "2.0",
		Result: map[string]interface{}{
			"tools": allTools,
		},
	}
}

// routeToServer routes a message to a specific MCP server
func (o *Orchestrator) routeToServer(msg MCPMessage) MCPMessage {
	// For now, return a placeholder response
	// In a real implementation, this would forward the message to the appropriate server
	return MCPMessage{
		ID:      msg.ID,
		JSONRPC: "2.0",
		Result:  map[string]interface{}{"message": "Not implemented yet"},
	}
}

// RegisterServer registers a new MCP server
func (o *Orchestrator) RegisterServer(server *MCPServer) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.servers[server.ID] = server
}

// GetServers returns all registered servers
func (o *Orchestrator) GetServers() map[string]*MCPServer {
	o.mu.RLock()
	defer o.mu.RUnlock()

	servers := make(map[string]*MCPServer)
	for k, v := range o.servers {
		servers[k] = v
	}
	return servers
}
