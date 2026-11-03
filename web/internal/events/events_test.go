package events

import (
	"bufio"
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func recv(t *testing.T, ch <-chan Event) Event {
	t.Helper()
	select {
	case e := <-ch:
		return e
	case <-time.After(3 * time.Second):
		t.Fatal("no event received")
		return Event{}
	}
}

func TestHubFanOutAndDedupe(t *testing.T) {
	h := NewHub()
	a, cancelA := h.Subscribe()
	b, cancelB := h.Subscribe()
	defer cancelA()
	defer cancelB()
	if !h.Publish(Event{ID: "1", Key: "k"}) {
		t.Fatal("first publish refused")
	}
	if recv(t, a).Key != "k" || recv(t, b).Key != "k" {
		t.Fatal("not delivered to both subscribers")
	}
	// The same id again (an event that came back through another server) is dropped
	if h.Publish(Event{ID: "1", Key: "k"}) {
		t.Fatal("duplicate published")
	}
	select {
	case e := <-a:
		t.Fatalf("duplicate delivered: %+v", e)
	case <-time.After(100 * time.Millisecond):
	}
}

func TestHubSlowSubscriberDoesNotBlock(t *testing.T) {
	h := NewHub()
	_, cancel := h.Subscribe() // never read
	defer cancel()
	done := make(chan struct{})
	go func() {
		for i := 0; i < subscriberQ*3; i++ {
			h.Publish(Event{ID: newID(), Key: "k"})
		}
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("a subscriber that does not read blocks the publisher")
	}
}

func TestPublishLocalGoesToBothHubs(t *testing.T) {
	s := NewService()
	l, cl := s.Local.Subscribe()
	a, ca := s.All.Subscribe()
	defer cl()
	defer ca()
	e := s.PublishLocal("exo-6.5.x", "h.example.org", "20260101.101010")
	if e.ID == "" || e.At == 0 {
		t.Fatalf("id/time not set: %+v", e)
	}
	if recv(t, l).ID != e.ID || recv(t, a).ID != e.ID {
		t.Fatal("event missing on a hub")
	}
}

func TestValidKey(t *testing.T) {
	for _, ok := range []string{"exo-6.5.x-SNAPSHOT", "a_b.c-1", "20260101.101010"} {
		if !ValidKey(ok) {
			t.Errorf("%q refused", ok)
		}
	}
	for _, bad := range []string{"", "a b", "a\nb", "a/b", "a;b", "é", strings.Repeat("a", 201)} {
		if ValidKey(bad) {
			t.Errorf("%q accepted", bad)
		}
	}
}

func TestIsSelf(t *testing.T) {
	if !IsSelf("https://Acceptance13.exoplatform.org", "acceptance13.exoplatform.org") {
		t.Error("same host not recognised")
	}
	if IsSelf("https://acceptance14.exoplatform.org", "acceptance13.exoplatform.org") || IsSelf("https://x", "") {
		t.Error("another server taken for this one")
	}
}

// Stream writes the frames of the hub and keeps the connection open.
func TestStream(t *testing.T) {
	hub := NewHub()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { Stream(w, r, hub) }))
	defer srv.Close()
	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if ct := resp.Header.Get("Content-Type"); !strings.HasPrefix(ct, "text/event-stream") || resp.Header.Get("Cache-Control") != "no-store" {
		t.Fatalf("headers: %q %q", ct, resp.Header.Get("Cache-Control"))
	}
	sc := bufio.NewScanner(resp.Body)
	// the connection comment arrives first: the subscription is then in place
	for sc.Scan() && !strings.HasPrefix(sc.Text(), ": connected") {
	}
	hub.Publish(Event{ID: "42", Key: "exo-x", Date: "d"})
	var data string
	for sc.Scan() {
		if d, ok := strings.CutPrefix(sc.Text(), "data: "); ok {
			data = d
			break
		}
	}
	if !strings.Contains(data, `"key":"exo-x"`) || !strings.Contains(data, `"id":"42"`) {
		t.Fatalf("frame: %q", data)
	}
}

// The relay republishes what another server streams, ignores what is not an event, and reconnects.
func TestRelay(t *testing.T) {
	peer := NewService()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/local-events" {
			http.NotFound(w, r)
			return
		}
		Stream(w, r, peer.Local)
	}))
	defer srv.Close()

	mine := NewHub()
	ch, cancelSub := mine.Subscribe()
	defer cancelSub()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	connects := make(chan struct{}, 4)
	go Relay(ctx, srv.Client(), srv.URL, mine, func() { connects <- struct{}{} })

	// wait for the relay to be connected: an event published before it is lost by design
	deadline := time.Now().Add(3 * time.Second)
	for {
		peer.Local.mu.Lock()
		n := len(peer.Local.subs)
		peer.Local.mu.Unlock()
		if n > 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("relay never connected")
		}
		time.Sleep(10 * time.Millisecond)
	}
	select {
	case <-connects:
	default:
		t.Fatal("onConnect not called when the stream was established")
	}
	e := peer.PublishLocal("exo-6.5.x", "h", "20260101.000000")
	got := recv(t, ch)
	if got.ID != e.ID || got.Key != "exo-6.5.x" {
		t.Fatalf("relayed event: %+v", got)
	}
}

func TestRelayIgnoresGarbageAndUnknownKeys(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.Write([]byte("data: not json\n\ndata: {\"id\":\"1\",\"key\":\"bad key\\n\"}\n\ndata: {\"key\":\"noid\"}\n\ndata: {\"id\":\"2\",\"key\":\"ok-1\"}\n\n"))
	}))
	defer srv.Close()
	hub := NewHub()
	ch, cancelSub := hub.Subscribe()
	defer cancelSub()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go Relay(ctx, srv.Client(), srv.URL, hub, nil)
	if got := recv(t, ch); got.ID != "2" {
		t.Fatalf("a bad frame went through: %+v", got)
	}
}
