// Package events carries the "instance deployed" notifications.
//
// adt.sh tells its own adt-web, once an instance has been deployed and started, with one POST on the local
// socket. The event is published on two hubs:
//
//   - Local: only what happened on this server. It is what /rest/local-events streams, and what the other
//     acceptance servers relay. Peers never publish on it, so an event cannot travel in circles.
//   - All: the local events plus the ones relayed from the other acceptance servers. It is what /events streams
//     to the browsers, so a page served by one server learns about a deployment done on another one.
//
// Events are not stored: a browser that is not connected when the instance is deployed misses it (the page still
// compares the deployment date it last saw).
package events

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// Event is one deployment: the instance (INSTANCE_KEY), the host it answers on and its DEPLOYMENT_DATE.
type Event struct {
	ID   string `json:"id"`
	Key  string `json:"key"`
	Host string `json:"host,omitempty"`
	Date string `json:"date,omitempty"`
	At   int64  `json:"at"`
}

const (
	seenMax      = 512              // event ids remembered to drop duplicates
	subscriberQ  = 32               // events a slow subscriber may lag behind before it misses some
	heartbeat    = 25 * time.Second // keeps proxies from closing an idle stream
	relayIdle    = 90 * time.Second // a peer silent for that long (no event, no heartbeat) is reconnected
	relayBackoff = 2 * time.Second
	relayMax     = 60 * time.Second
)

// Hub fans events out to its subscribers and drops the ones it has already seen.
type Hub struct {
	mu   sync.Mutex
	subs map[chan Event]struct{}
	seen map[string]struct{}
	ring []string
}

// NewHub returns an empty hub.
func NewHub() *Hub { return &Hub{subs: map[chan Event]struct{}{}, seen: map[string]struct{}{}} }

// Subscribe returns the channel of the next events and the function that ends the subscription.
func (h *Hub) Subscribe() (<-chan Event, func()) {
	ch := make(chan Event, subscriberQ)
	h.mu.Lock()
	h.subs[ch] = struct{}{}
	h.mu.Unlock()
	return ch, func() {
		h.mu.Lock()
		delete(h.subs, ch)
		h.mu.Unlock()
	}
}

// Publish delivers e to every subscriber; it is false (and nothing is sent) when its id was already published.
// A subscriber that does not keep up misses the event instead of holding the others back.
func (h *Hub) Publish(e Event) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, dup := h.seen[e.ID]; dup {
		return false
	}
	h.seen[e.ID] = struct{}{}
	h.ring = append(h.ring, e.ID)
	if len(h.ring) > seenMax {
		delete(h.seen, h.ring[0])
		h.ring = h.ring[1:]
	}
	for ch := range h.subs {
		select {
		case ch <- e:
		default:
		}
	}
	return true
}

// Service is the two hubs of a server.
type Service struct {
	Local, All *Hub
}

// NewService returns a service with empty hubs.
func NewService() *Service { return &Service{Local: NewHub(), All: NewHub()} }

// PublishLocal publishes an event that happened on this server and returns it (with its id and time).
func (s *Service) PublishLocal(key, host, date string) Event {
	e := Event{ID: newID(), Key: key, Host: host, Date: date, At: time.Now().Unix()}
	s.Local.Publish(e)
	s.All.Publish(e)
	return e
}

func newID() string {
	b := make([]byte, 12)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%d", time.Now().UnixNano())
	}
	return hex.EncodeToString(b)
}

// ValidKey tells whether s may be the key of an instance: the characters of an INSTANCE_KEY, nothing that could
// break a log line or an SSE frame.
func ValidKey(s string) bool {
	if s == "" || len(s) > 200 {
		return false
	}
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', r == '.', r == '_', r == '-':
		default:
			return false
		}
	}
	return true
}

// Stream writes the events of hub to w as server-sent events until the client goes away. A comment line is sent
// every 25 seconds so that the connection is never idle.
func Stream(w http.ResponseWriter, r *http.Request, hub *Hub) {
	rc := http.NewResponseController(w)
	h := w.Header()
	h.Set("Content-Type", "text/event-stream; charset=utf-8")
	h.Set("Cache-Control", "no-store")
	h.Set("X-Accel-Buffering", "no")
	_ = rc.SetWriteDeadline(time.Time{})
	w.WriteHeader(http.StatusOK)
	ch, cancel := hub.Subscribe()
	defer cancel()
	// "retry" is how long the browser waits before it reconnects
	if _, err := fmt.Fprint(w, "retry: 3000\n: connected\n\n"); err != nil || rc.Flush() != nil {
		return
	}
	tick := time.NewTicker(heartbeat)
	defer tick.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case e := <-ch:
			b, _ := json.Marshal(e)
			if _, err := fmt.Fprintf(w, "id: %s\ndata: %s\n\n", e.ID, b); err != nil {
				return
			}
		case <-tick.C:
			if _, err := fmt.Fprint(w, ": ping\n\n"); err != nil {
				return
			}
		}
		if rc.Flush() != nil {
			return
		}
	}
}

// Relay follows the /rest/local-events stream of another server and publishes what it sends on hub, until ctx ends.
// It reconnects with a growing delay: a server that is down never stops the others.
//
// onConnect (may be nil) runs each time the stream is (re)established. Events are not stored, so the ones sent
// while it was down are lost: the caller uses it to drop what it may have cached since.
func Relay(ctx context.Context, client *http.Client, server string, hub *Hub, onConnect func()) {
	endpoint := strings.TrimRight(server, "/") + "/rest/local-events"
	delay := relayBackoff
	for ctx.Err() == nil {
		connected, err := relayOnce(ctx, client, endpoint, hub, onConnect)
		if ctx.Err() != nil {
			return
		}
		if connected {
			delay = relayBackoff
		}
		if err != nil {
			log.Printf("events: %s: %v (retry in %s)", endpoint, err, delay)
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(delay):
		}
		if delay *= 2; delay > relayMax {
			delay = relayMax
		}
	}
}

func relayOnce(ctx context.Context, client *http.Client, endpoint string, hub *Hub, onConnect func()) (connected bool, err error) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return false, err
	}
	req.Header.Set("Accept", "text/event-stream")
	resp, err := client.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	if onConnect != nil {
		onConnect()
	}
	// Anything the peer sends, even a heartbeat, proves it is alive; silence for too long means the connection is dead
	idle := time.AfterFunc(relayIdle, cancel)
	defer idle.Stop()
	sc := bufio.NewScanner(resp.Body)
	sc.Buffer(make([]byte, 0, 4096), 64*1024)
	for sc.Scan() {
		idle.Reset(relayIdle)
		line := sc.Text()
		data, ok := strings.CutPrefix(line, "data: ")
		if !ok {
			continue
		}
		var e Event
		if json.Unmarshal([]byte(data), &e) != nil || e.ID == "" || !ValidKey(e.Key) {
			continue // not ours: ignore it
		}
		hub.Publish(e)
	}
	if err := sc.Err(); err != nil {
		return true, err
	}
	return true, fmt.Errorf("stream closed")
}

// IsSelf tells whether server (an ACCEPTANCE_SERVERS entry) is this very server, which has nothing to relay
// from itself.
func IsSelf(server, acceptanceHost string) bool {
	u, err := url.Parse(server)
	return err == nil && acceptanceHost != "" && strings.EqualFold(u.Hostname(), acceptanceHost)
}
