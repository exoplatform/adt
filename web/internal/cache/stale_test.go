package cache

import (
	"sync/atomic"
	"testing"
	"time"
)

// Refresh recomputes what was asked for and returns when the new values are there (Invalidate only starts the
// recomputation): the caller can announce that the data changed and be sure that the next reader sees the new data.
func TestStaleRefreshWaitsForTheNewValues(t *testing.T) {
	s := NewStale[int]()
	var n atomic.Int32
	build := func() int { time.Sleep(30 * time.Millisecond); return int(n.Add(1)) }
	other := func() int { return 100 }
	if got := s.Get("a", time.Hour, build); got != 1 {
		t.Fatalf("first value %d", got)
	}
	s.Get("b", time.Hour, other)

	s.Refresh()

	if got := s.Get("a", time.Hour, build); got != 2 {
		t.Fatalf("after Refresh the value is %d, want the recomputed 2 (a stale 1 would mean it only started)", got)
	}
	if got := s.Get("b", time.Hour, other); got != 100 {
		t.Fatalf("b = %d", got)
	}
	if n.Load() != 2 {
		t.Fatalf("build ran %d times", n.Load())
	}
}

// Nothing was asked for: nothing is built, and it returns at once.
func TestStaleRefreshOfAnEmptySetDoesNothing(t *testing.T) {
	s := NewStale[int]()
	done := make(chan struct{})
	go func() { s.Refresh(); close(done) }()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("Refresh of an empty set did not return")
	}
}
