package performance

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// Connection represents a connection to an MCP server
type Connection struct {
	ID         string
	ServerID   string
	Address    string
	Port       int
	CreatedAt  time.Time
	LastUsed   time.Time
	UsageCount int
	IsHealthy  bool
	IsBusy     bool
	mu         sync.RWMutex
}

// ConnectionPool manages a pool of connections to MCP servers
type ConnectionPool struct {
	serverID    string
	connections []*Connection
	maxSize     int
	minSize     int
	mu          sync.RWMutex
	healthCheck HealthChecker
	factory     ConnectionFactory
	stats       PoolStats
}

// PoolStats holds connection pool statistics
type PoolStats struct {
	TotalConnections     int           `json:"total_connections"`
	ActiveConnections    int           `json:"active_connections"`
	IdleConnections      int           `json:"idle_connections"`
	BusyConnections      int           `json:"busy_connections"`
	CreatedConnections   int64         `json:"created_connections"`
	DestroyedConnections int64         `json:"destroyed_connections"`
	TotalRequests        int64         `json:"total_requests"`
	FailedRequests       int64         `json:"failed_requests"`
	AverageWaitTime      time.Duration `json:"average_wait_time"`
	LastReset            time.Time     `json:"last_reset"`
}

// PoolConfig defines connection pool configuration
type PoolConfig struct {
	ServerID            string        `json:"server_id"`
	MinConnections      int           `json:"min_connections"`
	MaxConnections      int           `json:"max_connections"`
	ConnectionTimeout   time.Duration `json:"connection_timeout"`
	IdleTimeout         time.Duration `json:"idle_timeout"`
	HealthCheckInterval time.Duration `json:"health_check_interval"`
	MaxRetries          int           `json:"max_retries"`
	RetryBackoff        time.Duration `json:"retry_backoff"`
}

// ConnectionFactory creates new connections
type ConnectionFactory interface {
	CreateConnection(serverID string) (*Connection, error)
	DestroyConnection(conn *Connection) error
	ValidateConnection(conn *Connection) bool
}

// HealthChecker checks connection health
type HealthChecker interface {
	CheckHealth(conn *Connection) bool
	IsHealthy(conn *Connection) bool
}

// LoadBalancer manages multiple connection pools
type LoadBalancer struct {
	pools    map[string]*ConnectionPool
	mu       sync.RWMutex
	strategy LoadBalancingStrategy
	circuit  *CircuitBreaker
}

// LoadBalancingStrategy defines load balancing algorithm
type LoadBalancingStrategy string

const (
	RoundRobin       LoadBalancingStrategy = "round_robin"
	LeastConnections LoadBalancingStrategy = "least_connections"
	HealthyFirst     LoadBalancingStrategy = "healthy_first"
	WeightedRandom   LoadBalancingStrategy = "weighted_random"
)

// CircuitBreaker prevents cascading failures
type CircuitBreaker struct {
	mu           sync.RWMutex
	state        CircuitState
	failures     int
	lastFailure  time.Time
	timeout      time.Duration
	maxFailures  int
	resetTimeout time.Duration
}

// CircuitState represents circuit breaker state
type CircuitState string

const (
	CircuitClosed   CircuitState = "closed"
	CircuitOpen     CircuitState = "open"
	CircuitHalfOpen CircuitState = "half_open"
)

// NewConnectionPool creates a new connection pool
func NewConnectionPool(config PoolConfig, factory ConnectionFactory, healthChecker HealthChecker) *ConnectionPool {
	pool := &ConnectionPool{
		serverID:    config.ServerID,
		connections: make([]*Connection, 0, config.MaxConnections),
		maxSize:     config.MaxConnections,
		minSize:     config.MinConnections,
		healthCheck: healthChecker,
		factory:     factory,
		stats:       PoolStats{LastReset: time.Now()},
	}

	// Initialize minimum connections
	pool.initializeConnections()

	// Start health check routine
	go pool.healthCheckRoutine(config.HealthCheckInterval)

	// Start idle connection cleanup
	go pool.cleanupIdleConnections(config.IdleTimeout)

	return pool
}

// GetConnection retrieves a connection from the pool
func (p *ConnectionPool) GetConnection(ctx context.Context) (*Connection, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.stats.TotalRequests++

	// Find an available healthy connection
	for _, conn := range p.connections {
		if p.isConnectionAvailable(conn) {
			conn.mu.Lock()
			conn.IsBusy = true
			conn.LastUsed = time.Now()
			conn.UsageCount++
			conn.mu.Unlock()

			p.updateStats()
			return conn, nil
		}
	}

	// No available connection, try to create a new one
	if len(p.connections) < p.maxSize {
		conn, err := p.createConnection()
		if err != nil {
			p.stats.FailedRequests++
			return nil, err
		}

		conn.mu.Lock()
		conn.IsBusy = true
		conn.LastUsed = time.Now()
		conn.UsageCount++
		conn.mu.Unlock()

		p.connections = append(p.connections, conn)
		p.updateStats()
		return conn, nil
	}

	// Pool is full, wait for a connection to become available
	return p.waitForConnection(ctx)
}

// ReturnConnection returns a connection to the pool
func (p *ConnectionPool) ReturnConnection(conn *Connection) {
	if conn == nil {
		return
	}

	conn.mu.Lock()
	conn.IsBusy = false
	conn.LastUsed = time.Now()
	conn.mu.Unlock()

	p.mu.Lock()
	p.updateStats()
	p.mu.Unlock()
}

// RemoveConnection removes a connection from the pool
func (p *ConnectionPool) RemoveConnection(conn *Connection) {
	p.mu.Lock()
	defer p.mu.Unlock()

	for i, c := range p.connections {
		if c.ID == conn.ID {
			// Remove from slice
			p.connections = append(p.connections[:i], p.connections[i+1:]...)

			// Destroy the connection
			p.factory.DestroyConnection(conn)
			p.stats.DestroyedConnections++

			break
		}
	}

	p.updateStats()
}

// GetStats returns pool statistics
func (p *ConnectionPool) GetStats() PoolStats {
	p.mu.RLock()
	defer p.mu.RUnlock()

	return p.stats
}

// Close closes all connections in the pool
func (p *ConnectionPool) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	for _, conn := range p.connections {
		p.factory.DestroyConnection(conn)
	}

	p.connections = p.connections[:0]
	p.updateStats()

	return nil
}

// initializeConnections creates minimum number of connections
func (p *ConnectionPool) initializeConnections() {
	for i := 0; i < p.minSize; i++ {
		conn, err := p.createConnection()
		if err != nil {
			continue
		}

		p.connections = append(p.connections, conn)
	}

	p.updateStats()
}

// createConnection creates a new connection
func (p *ConnectionPool) createConnection() (*Connection, error) {
	conn, err := p.factory.CreateConnection(p.serverID)
	if err != nil {
		return nil, err
	}

	conn.ID = fmt.Sprintf("%s-%d", p.serverID, time.Now().UnixNano())
	conn.CreatedAt = time.Now()
	conn.LastUsed = time.Now()
	conn.IsHealthy = true

	p.stats.CreatedConnections++

	return conn, nil
}

// isConnectionAvailable checks if a connection is available for use
func (p *ConnectionPool) isConnectionAvailable(conn *Connection) bool {
	conn.mu.RLock()
	defer conn.mu.RUnlock()

	return conn.IsHealthy && !conn.IsBusy
}

// waitForConnection waits for a connection to become available
func (p *ConnectionPool) waitForConnection(ctx context.Context) (*Connection, error) {
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			p.mu.Lock()
			for _, conn := range p.connections {
				if p.isConnectionAvailable(conn) {
					conn.mu.Lock()
					conn.IsBusy = true
					conn.LastUsed = time.Now()
					conn.UsageCount++
					conn.mu.Unlock()

					p.updateStats()
					p.mu.Unlock()
					return conn, nil
				}
			}
			p.mu.Unlock()
		}
	}
}

// healthCheckRoutine periodically checks connection health
func (p *ConnectionPool) healthCheckRoutine(interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for range ticker.C {
		p.mu.Lock()
		unhealthyConns := make([]*Connection, 0)

		for _, conn := range p.connections {
			if !p.healthCheck.CheckHealth(conn) {
				conn.mu.Lock()
				conn.IsHealthy = false
				conn.mu.Unlock()

				if !conn.IsBusy {
					unhealthyConns = append(unhealthyConns, conn)
				}
			}
		}

		// Remove unhealthy connections
		for _, conn := range unhealthyConns {
			p.RemoveConnection(conn)
		}

		p.mu.Unlock()
	}
}

// cleanupIdleConnections removes idle connections
func (p *ConnectionPool) cleanupIdleConnections(idleTimeout time.Duration) {
	ticker := time.NewTicker(idleTimeout)
	defer ticker.Stop()

	for range ticker.C {
		p.mu.Lock()
		now := time.Now()
		idleConns := make([]*Connection, 0)

		for _, conn := range p.connections {
			conn.mu.RLock()
			if !conn.IsBusy && now.Sub(conn.LastUsed) > idleTimeout {
				idleConns = append(idleConns, conn)
			}
			conn.mu.RUnlock()
		}

		// Remove idle connections (keep minimum)
		for _, conn := range idleConns {
			if len(p.connections) > p.minSize {
				p.RemoveConnection(conn)
			}
		}

		p.mu.Unlock()
	}
}

// updateStats updates pool statistics
func (p *ConnectionPool) updateStats() {
	p.stats.TotalConnections = len(p.connections)
	p.stats.ActiveConnections = 0
	p.stats.IdleConnections = 0
	p.stats.BusyConnections = 0

	for _, conn := range p.connections {
		conn.mu.RLock()
		if conn.IsHealthy {
			p.stats.ActiveConnections++
		}
		if conn.IsBusy {
			p.stats.BusyConnections++
		} else {
			p.stats.IdleConnections++
		}
		conn.mu.RUnlock()
	}
}

// NewLoadBalancer creates a new load balancer
func NewLoadBalancer(strategy LoadBalancingStrategy) *LoadBalancer {
	return &LoadBalancer{
		pools:    make(map[string]*ConnectionPool),
		strategy: strategy,
		circuit:  NewCircuitBreaker(5, 30*time.Second, 60*time.Second),
	}
}

// AddPool adds a connection pool to the load balancer
func (lb *LoadBalancer) AddPool(serverID string, pool *ConnectionPool) {
	lb.mu.Lock()
	defer lb.mu.Unlock()

	lb.pools[serverID] = pool
}

// RemovePool removes a connection pool from the load balancer
func (lb *LoadBalancer) RemovePool(serverID string) {
	lb.mu.Lock()
	defer lb.mu.Unlock()

	if pool, exists := lb.pools[serverID]; exists {
		pool.Close()
		delete(lb.pools, serverID)
	}
}

// GetConnection gets a connection using load balancing
func (lb *LoadBalancer) GetConnection(ctx context.Context, serverID string) (*Connection, error) {
	lb.mu.RLock()
	defer lb.mu.RUnlock()

	// Check circuit breaker
	if !lb.circuit.Allow() {
		return nil, fmt.Errorf("circuit breaker is open")
	}

	pool, exists := lb.pools[serverID]
	if !exists {
		return nil, fmt.Errorf("pool for server %s not found", serverID)
	}

	conn, err := pool.GetConnection(ctx)
	if err != nil {
		lb.circuit.RecordFailure()
		return nil, err
	}

	lb.circuit.RecordSuccess()
	return conn, nil
}

// GetAllPools returns all connection pools
func (lb *LoadBalancer) GetAllPools() map[string]*ConnectionPool {
	lb.mu.RLock()
	defer lb.mu.RUnlock()

	pools := make(map[string]*ConnectionPool)
	for k, v := range lb.pools {
		pools[k] = v
	}

	return pools
}

// GetPoolStats returns statistics for all pools
func (lb *LoadBalancer) GetPoolStats() map[string]PoolStats {
	lb.mu.RLock()
	defer lb.mu.RUnlock()

	stats := make(map[string]PoolStats)
	for serverID, pool := range lb.pools {
		stats[serverID] = pool.GetStats()
	}

	return stats
}

// NewCircuitBreaker creates a new circuit breaker
func NewCircuitBreaker(maxFailures int, timeout time.Duration, resetTimeout time.Duration) *CircuitBreaker {
	return &CircuitBreaker{
		state:        CircuitClosed,
		timeout:      timeout,
		maxFailures:  maxFailures,
		resetTimeout: resetTimeout,
	}
}

// Allow checks if requests are allowed through the circuit breaker
func (cb *CircuitBreaker) Allow() bool {
	cb.mu.RLock()
	defer cb.mu.RUnlock()

	switch cb.state {
	case CircuitClosed:
		return true
	case CircuitOpen:
		if time.Since(cb.lastFailure) > cb.resetTimeout {
			cb.state = CircuitHalfOpen
			return true
		}
		return false
	case CircuitHalfOpen:
		return true
	default:
		return false
	}
}

// RecordSuccess records a successful request
func (cb *CircuitBreaker) RecordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures = 0
	cb.state = CircuitClosed
}

// RecordFailure records a failed request
func (cb *CircuitBreaker) RecordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures++
	cb.lastFailure = time.Now()

	if cb.failures >= cb.maxFailures {
		cb.state = CircuitOpen
	}
}

// GetState returns the current circuit breaker state
func (cb *CircuitBreaker) GetState() CircuitState {
	cb.mu.RLock()
	defer cb.mu.RUnlock()

	return cb.state
}

// GetFailures returns the current failure count
func (cb *CircuitBreaker) GetFailures() int {
	cb.mu.RLock()
	defer cb.mu.RUnlock()

	return cb.failures
}

// Reset resets the circuit breaker
func (cb *CircuitBreaker) Reset() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures = 0
	cb.state = CircuitClosed
}
