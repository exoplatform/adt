package cache

import (
	"sort"
	"time"
)

// Info describes one live entry, for /debug-caches.
type Info struct {
	Key     string
	Created time.Time
	TTL     time.Duration // 0 = never expires
	Hits    int64
}

// Stats are the counters of the cache.
type Stats struct {
	Entries               int
	Hits, Misses, Inserts int64
	Started               time.Time
}

// Inspect lists the live entries sorted by key, with the cache statistics. Expired entries are skipped.
func (c *Cache) Inspect() ([]Info, Stats) {
	c.mu.Lock()
	defer c.mu.Unlock()
	now := c.now()
	list := make([]Info, 0, len(c.m))
	for k, e := range c.m {
		if !e.expires.IsZero() && !now.Before(e.expires) {
			continue
		}
		in := Info{Key: k, Created: e.created, Hits: e.hits}
		if !e.expires.IsZero() {
			in.TTL = e.expires.Sub(e.created)
		}
		list = append(list, in)
	}
	sort.Slice(list, func(i, j int) bool { return list[i].Key < list[j].Key })
	return list, Stats{Entries: len(list), Hits: c.hitCount, Misses: c.missCount, Inserts: c.ins, Started: c.started}
}
