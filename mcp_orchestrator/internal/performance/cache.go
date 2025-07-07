package performance

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

// CacheItem represents a cached item
type CacheItem struct {
	Key         string      `json:"key"`
	Value       interface{} `json:"value"`
	CreatedAt   time.Time   `json:"created_at"`
	ExpiresAt   time.Time   `json:"expires_at"`
	AccessCount int         `json:"access_count"`
	LastAccess  time.Time   `json:"last_access"`
}

// Cache provides in-memory caching with TTL and LRU eviction
type Cache struct {
	items      map[string]*CacheItem
	mu         sync.RWMutex
	maxSize    int
	defaultTTL time.Duration
	stats      CacheStats
}

// CacheStats holds cache performance statistics
type CacheStats struct {
	Hits      int64     `json:"hits"`
	Misses    int64     `json:"misses"`
	Evictions int64     `json:"evictions"`
	Size      int       `json:"size"`
	HitRate   float64   `json:"hit_rate"`
	LastReset time.Time `json:"last_reset"`
}

// CacheConfig defines cache configuration
type CacheConfig struct {
	MaxSize         int           `json:"max_size"`
	DefaultTTL      time.Duration `json:"default_ttl"`
	CleanupInterval time.Duration `json:"cleanup_interval"`
}

// NewCache creates a new cache instance
func NewCache(config CacheConfig) *Cache {
	cache := &Cache{
		items:      make(map[string]*CacheItem),
		maxSize:    config.MaxSize,
		defaultTTL: config.DefaultTTL,
		stats:      CacheStats{LastReset: time.Now()},
	}

	// Start cleanup goroutine
	go cache.cleanup(config.CleanupInterval)

	return cache
}

// Get retrieves an item from the cache
func (c *Cache) Get(key string) (interface{}, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	item, exists := c.items[key]
	if !exists {
		c.stats.Misses++
		c.updateHitRate()
		return nil, false
	}

	// Check if item has expired
	if time.Now().After(item.ExpiresAt) {
		c.stats.Misses++
		c.updateHitRate()
		return nil, false
	}

	// Update access statistics
	item.AccessCount++
	item.LastAccess = time.Now()
	c.stats.Hits++
	c.updateHitRate()

	return item.Value, true
}

// Set stores an item in the cache
func (c *Cache) Set(key string, value interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Use default TTL if not specified
	if ttl == 0 {
		ttl = c.defaultTTL
	}

	now := time.Now()
	item := &CacheItem{
		Key:         key,
		Value:       value,
		CreatedAt:   now,
		ExpiresAt:   now.Add(ttl),
		AccessCount: 1,
		LastAccess:  now,
	}

	// Check if we need to evict items
	if len(c.items) >= c.maxSize {
		c.evictLRU()
	}

	c.items[key] = item
	c.stats.Size = len(c.items)
}

// Delete removes an item from the cache
func (c *Cache) Delete(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()

	delete(c.items, key)
	c.stats.Size = len(c.items)
}

// Clear removes all items from the cache
func (c *Cache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.items = make(map[string]*CacheItem)
	c.stats.Size = 0
}

// GetStats returns cache statistics
func (c *Cache) GetStats() CacheStats {
	c.mu.RLock()
	defer c.mu.RUnlock()

	return c.stats
}

// GetAll returns all cache items (for debugging)
func (c *Cache) GetAll() map[string]*CacheItem {
	c.mu.RLock()
	defer c.mu.RUnlock()

	items := make(map[string]*CacheItem)
	for k, v := range c.items {
		items[k] = v
	}

	return items
}

// evictLRU removes the least recently used item
func (c *Cache) evictLRU() {
	var oldestKey string
	var oldestTime time.Time

	for key, item := range c.items {
		if oldestKey == "" || item.LastAccess.Before(oldestTime) {
			oldestKey = key
			oldestTime = item.LastAccess
		}
	}

	if oldestKey != "" {
		delete(c.items, oldestKey)
		c.stats.Evictions++
	}
}

// cleanup removes expired items periodically
func (c *Cache) cleanup(interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for range ticker.C {
		c.mu.Lock()
		now := time.Now()
		expired := make([]string, 0)

		for key, item := range c.items {
			if now.After(item.ExpiresAt) {
				expired = append(expired, key)
			}
		}

		for _, key := range expired {
			delete(c.items, key)
		}

		c.stats.Size = len(c.items)
		c.mu.Unlock()
	}
}

// updateHitRate calculates the cache hit rate
func (c *Cache) updateHitRate() {
	total := c.stats.Hits + c.stats.Misses
	if total > 0 {
		c.stats.HitRate = float64(c.stats.Hits) / float64(total) * 100
	}
}

// ToolCache provides specialized caching for tool-related data
type ToolCache struct {
	toolsCache    *Cache
	responseCache *Cache
	serverCache   *Cache
	profileCache  *Cache
}

// NewToolCache creates a new tool cache
func NewToolCache() *ToolCache {
	return &ToolCache{
		toolsCache: NewCache(CacheConfig{
			MaxSize:         1000,
			DefaultTTL:      5 * time.Minute,
			CleanupInterval: 1 * time.Minute,
		}),
		responseCache: NewCache(CacheConfig{
			MaxSize:         500,
			DefaultTTL:      30 * time.Second,
			CleanupInterval: 30 * time.Second,
		}),
		serverCache: NewCache(CacheConfig{
			MaxSize:         100,
			DefaultTTL:      1 * time.Minute,
			CleanupInterval: 30 * time.Second,
		}),
		profileCache: NewCache(CacheConfig{
			MaxSize:         50,
			DefaultTTL:      10 * time.Minute,
			CleanupInterval: 2 * time.Minute,
		}),
	}
}

// CacheToolList caches the tool list for a server
func (tc *ToolCache) CacheToolList(serverID string, tools interface{}) {
	key := fmt.Sprintf("tools:%s", serverID)
	tc.toolsCache.Set(key, tools, 5*time.Minute)
}

// GetCachedToolList retrieves cached tool list
func (tc *ToolCache) GetCachedToolList(serverID string) (interface{}, bool) {
	key := fmt.Sprintf("tools:%s", serverID)
	return tc.toolsCache.Get(key)
}

// CacheResponse caches a tool response
func (tc *ToolCache) CacheResponse(toolName, serverID string, args map[string]interface{}, response interface{}) {
	key := tc.generateResponseKey(toolName, serverID, args)
	tc.responseCache.Set(key, response, 30*time.Second)
}

// GetCachedResponse retrieves cached tool response
func (tc *ToolCache) GetCachedResponse(toolName, serverID string, args map[string]interface{}) (interface{}, bool) {
	key := tc.generateResponseKey(toolName, serverID, args)
	return tc.responseCache.Get(key)
}

// CacheServerStatus caches server status
func (tc *ToolCache) CacheServerStatus(serverID string, status interface{}) {
	key := fmt.Sprintf("server:%s", serverID)
	tc.serverCache.Set(key, status, 1*time.Minute)
}

// GetCachedServerStatus retrieves cached server status
func (tc *ToolCache) GetCachedServerStatus(serverID string) (interface{}, bool) {
	key := fmt.Sprintf("server:%s", serverID)
	return tc.serverCache.Get(key)
}

// CacheProfile caches a profile
func (tc *ToolCache) CacheProfile(profileID string, profile interface{}) {
	key := fmt.Sprintf("profile:%s", profileID)
	tc.profileCache.Set(key, profile, 10*time.Minute)
}

// GetCachedProfile retrieves cached profile
func (tc *ToolCache) GetCachedProfile(profileID string) (interface{}, bool) {
	key := fmt.Sprintf("profile:%s", profileID)
	return tc.profileCache.Get(key)
}

// InvalidateServer removes all cached data for a server
func (tc *ToolCache) InvalidateServer(serverID string) {
	// Remove tools cache
	tc.toolsCache.Delete(fmt.Sprintf("tools:%s", serverID))

	// Remove server status cache
	tc.serverCache.Delete(fmt.Sprintf("server:%s", serverID))

	// Remove response cache for this server (more complex)
	tc.invalidateResponsesForServer(serverID)
}

// InvalidateProfile removes cached profile data
func (tc *ToolCache) InvalidateProfile(profileID string) {
	tc.profileCache.Delete(fmt.Sprintf("profile:%s", profileID))
}

// GetCacheStats returns statistics for all caches
func (tc *ToolCache) GetCacheStats() map[string]CacheStats {
	return map[string]CacheStats{
		"tools":     tc.toolsCache.GetStats(),
		"responses": tc.responseCache.GetStats(),
		"servers":   tc.serverCache.GetStats(),
		"profiles":  tc.profileCache.GetStats(),
	}
}

// generateResponseKey creates a unique key for caching responses
func (tc *ToolCache) generateResponseKey(toolName, serverID string, args map[string]interface{}) string {
	// Create a deterministic key based on tool name, server, and arguments
	argsJSON, _ := json.Marshal(args)
	data := fmt.Sprintf("%s:%s:%s", toolName, serverID, string(argsJSON))
	hash := md5.Sum([]byte(data))
	return fmt.Sprintf("response:%s", hex.EncodeToString(hash[:]))
}

// invalidateResponsesForServer removes all cached responses for a server
func (tc *ToolCache) invalidateResponsesForServer(serverID string) {
	// Get all cached responses and remove ones for this server
	items := tc.responseCache.GetAll()
	for key, item := range items {
		// This is a simplified approach - in a real implementation,
		// you might want to store server metadata with the cache key
		if responseData, ok := item.Value.(map[string]interface{}); ok {
			if responseData["server_id"] == serverID {
				tc.responseCache.Delete(key)
			}
		}
	}
}

// WarmupCache pre-loads frequently used data
func (tc *ToolCache) WarmupCache(servers []string) {
	// This would typically load tool lists, server statuses, etc.
	// Implementation would depend on your specific use case
	for _, serverID := range servers {
		// Pre-load server status (placeholder)
		tc.CacheServerStatus(serverID, map[string]interface{}{
			"warmed_up": true,
			"timestamp": time.Now(),
		})
	}
}
