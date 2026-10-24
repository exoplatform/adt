package cache

import (
	"sync"
	"time"
)

// Stale is a set of values computed by build functions and served from memory. A value older than its ttl is
// still returned at once while a background refresh recomputes it, so a visitor never waits for a recomputation:
// only the very first computation of a key is waited for, and concurrent callers of that key queue on it instead
// of repeating the work. Unlike Cache, entries are never dropped: Invalidate marks them out of date and
// refreshes them in the background.
type Stale[T any] struct {
	mu sync.Mutex
	m  map[string]*staleEntry[T]
}

type staleEntry[T any] struct {
	mu         sync.Mutex
	val        T
	at         time.Time
	has        bool
	refreshing bool
	build      func() T
}

var (
	staleMu   sync.Mutex
	staleSets []interface{ Invalidate() }
)

// NewStale declares a set of stale-while-refreshing values. InvalidateAll reaches every set.
func NewStale[T any]() *Stale[T] {
	s := &Stale[T]{m: map[string]*staleEntry[T]{}}
	staleMu.Lock()
	staleSets = append(staleSets, s)
	staleMu.Unlock()
	return s
}

// Get returns the value of key, computing it with build when there is none yet. A value older than ttl is
// returned as it is and refreshed in the background.
func (s *Stale[T]) Get(key string, ttl time.Duration, build func() T) T {
	s.mu.Lock()
	e, ok := s.m[key]
	if !ok {
		e = &staleEntry[T]{}
		s.m[key] = e
	}
	s.mu.Unlock()

	e.mu.Lock()
	defer e.mu.Unlock()
	e.build = build
	if e.has {
		if time.Since(e.at) >= ttl {
			e.refreshLocked()
		}
		return e.val
	}
	e.val, e.at, e.has = build(), time.Now(), true
	return e.val
}

// refreshLocked starts a background refresh unless one is running. The caller holds e.mu.
func (e *staleEntry[T]) refreshLocked() {
	if e.refreshing {
		return
	}
	e.refreshing = true
	build := e.build
	go func() {
		v := build()
		e.mu.Lock()
		e.val, e.at, e.refreshing = v, time.Now(), false
		e.mu.Unlock()
	}()
}

// Invalidate marks every value of the set out of date and refreshes them in the background; callers keep getting
// the previous values until the new ones are ready.
func (s *Stale[T]) Invalidate() {
	s.mu.Lock()
	entries := make([]*staleEntry[T], 0, len(s.m))
	for _, e := range s.m {
		entries = append(entries, e)
	}
	s.mu.Unlock()
	for _, e := range entries {
		e.mu.Lock()
		if e.has {
			e.at = time.Time{}
			e.refreshLocked()
		}
		e.mu.Unlock()
	}
}

// InvalidateAll invalidates every Stale set: what "clear the caches" means for the values that are never dropped.
func InvalidateAll() {
	staleMu.Lock()
	sets := append([]interface{ Invalidate() }(nil), staleSets...)
	staleMu.Unlock()
	for _, s := range sets {
		s.Invalidate()
	}
}
