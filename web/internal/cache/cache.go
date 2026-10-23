// Package cache is the TTL cache with stale-while-revalidate.
//
// The server is one process, so a mutex-protected map is enough. Values are stored by reference: callers must treat what they Get as
// read-only (the instance maps are shared between requests).
package cache

import (
	"sync"
	"time"
)

type entry struct {
	v       any
	expires time.Time // zero = never
	created time.Time // for Inspect (/debug-caches)
	hits    int64
}

// Cache is a concurrency-safe in-memory TTL cache.
type Cache struct {
	mu  sync.Mutex
	m   map[string]entry
	now func() time.Time
	// statistics for Inspect
	started                  time.Time
	hitCount, missCount, ins int64
}

// Default is the process-wide cache: share it between services so that Clear
// empties every cached thing at once.
var Default = New()

// New builds an empty cache.
func New() *Cache { return &Cache{m: map[string]entry{}, now: time.Now, started: time.Now()} }

// Get returns the value and true, or nil and false when absent or expired.
func (c *Cache) Get(key string) (any, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.m[key]
	if !ok {
		c.missCount++
		return nil, false
	}
	if !e.expires.IsZero() && !c.now().Before(e.expires) {
		delete(c.m, key)
		c.missCount++
		return nil, false
	}
	c.hitCount++
	e.hits++
	c.m[key] = e
	return e.v, true
}

// Set stores a value for ttl (ttl <= 0 means no expiry).
func (c *Cache) Set(key string, v any, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e := entry{v: v, created: c.now()}
	c.ins++
	if ttl > 0 {
		e.expires = c.now().Add(ttl)
	}
	// opportunistic sweep so that expired entries of rarely read keys do not pile up
	if len(c.m) > 256 {
		now := c.now()
		for k, o := range c.m {
			if !o.expires.IsZero() && !now.Before(o.expires) {
				delete(c.m, k)
			}
		}
	}
	c.m[key] = e
}

// Delete removes one key.
func (c *Cache) Delete(key string) {
	c.mu.Lock()
	delete(c.m, key)
	c.mu.Unlock()
}

// Clear drops everything.
func (c *Cache) Clear() {
	c.mu.Lock()
	c.m = map[string]entry{}
	c.mu.Unlock()
}

// RunAfterResponse runs fn in the background, at most once per ttl for a lockKey
// (the lock is a cache entry, so Clear releases it). The caller has already got its answer
// (a stale copy) when this is used, so it never waits for fn. It reports whether fn was started.
func (c *Cache) RunAfterResponse(lockKey string, ttl time.Duration, fn func()) bool {
	c.mu.Lock()
	if e, ok := c.m[lockKey]; ok && (e.expires.IsZero() || c.now().Before(e.expires)) {
		c.mu.Unlock()
		return false
	}
	c.m[lockKey] = entry{v: 1, expires: c.now().Add(ttl), created: c.now()}
	c.mu.Unlock()
	go func() {
		defer func() { _ = recover() }() // a failing refresh must not take the server down
		fn()
	}()
	return true
}
