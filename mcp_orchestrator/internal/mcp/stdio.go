package mcp

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"sync"
)

// StdioServer handles stdio communication with Claude Desktop
type StdioServer struct {
	orchestrator *Orchestrator
	reader       *bufio.Reader
	writer       *bufio.Writer
	mu           sync.Mutex
	ctx          context.Context
	cancel       context.CancelFunc
}

// NewStdioServer creates a new stdio server
func NewStdioServer(orchestrator *Orchestrator) *StdioServer {
	ctx, cancel := context.WithCancel(context.Background())

	return &StdioServer{
		orchestrator: orchestrator,
		reader:       bufio.NewReader(os.Stdin),
		writer:       bufio.NewWriter(os.Stdout),
		ctx:          ctx,
		cancel:       cancel,
	}
}

// Start starts the stdio server
func (s *StdioServer) Start() error {
	log.Println("Starting MCP stdio server...")

	for {
		select {
		case <-s.ctx.Done():
			return nil
		default:
			if err := s.handleMessage(); err != nil {
				if err == io.EOF {
					log.Println("Stdio connection closed")
					return nil
				}
				log.Printf("Error handling message: %v", err)
				return err
			}
		}
	}
}

// Stop stops the stdio server
func (s *StdioServer) Stop() {
	s.cancel()
}

// handleMessage handles a single message from stdin
func (s *StdioServer) handleMessage() error {
	// Read line from stdin
	line, err := s.reader.ReadString('\n')
	if err != nil {
		return err
	}

	// Parse JSON message
	var msg MCPMessage
	if err := json.Unmarshal([]byte(line), &msg); err != nil {
		log.Printf("Error parsing message: %v", err)
		return s.sendErrorResponse(nil, fmt.Sprintf("Invalid JSON: %v", err))
	}

	// Route the message
	response := s.orchestrator.routeMessage(msg)

	// Send response
	return s.sendResponse(response)
}

// sendResponse sends a response message to stdout
func (s *StdioServer) sendResponse(msg MCPMessage) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	data, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("failed to marshal response: %v", err)
	}

	// Write to stdout with newline
	if _, err := s.writer.Write(data); err != nil {
		return err
	}
	if err := s.writer.WriteByte('\n'); err != nil {
		return err
	}

	return s.writer.Flush()
}

// sendErrorResponse sends an error response
func (s *StdioServer) sendErrorResponse(id interface{}, message string) error {
	return s.sendResponse(MCPMessage{
		ID:      id,
		JSONRPC: "2.0",
		Error: map[string]interface{}{
			"code":    -32700,
			"message": message,
		},
	})
}
