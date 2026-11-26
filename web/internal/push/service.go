package push

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"sync"
	"syscall"
	"time"

	"github.com/exoplatform/adt/web/internal/events"
)

// Limits on what a signed-in visitor can make the server keep and call.
const (
	MaxPerUser   = 10  // browsers one login may register
	MaxInstances = 500 // instances one browser may follow
	maxTotal     = 2000
	sendWorkers  = 8
	sendTimeout  = 10 * time.Second
	messageTTL   = 3600 // seconds a push service keeps a message for a browser that is offline
	// A page registers again at every load: a browser that has not shown up for that long is gone (the subscriptions
	// would otherwise only leave when a push to them is answered 404/410, and they count against maxTotal)
	staleAfter = 180 * 24 * time.Hour
)

// Subscription is one browser (one PushSubscription) and the instances it wants to hear about.
type Subscription struct {
	Endpoint string `json:"endpoint"`
	P256dh   string `json:"p256dh"`
	Auth     string `json:"auth"`
	User     string `json:"user"`
	// Session ties the subscription to the login session that registered it (its id, as sessions.ID): the person
	// signing out, an eviction or a block stop the notifications. It is empty when Apache gave none (development). The
	// end of the session (8 hours) does not: the point is to hear of a deployment while away.
	Session   string    `json:"session,omitempty"`
	Instances []string  `json:"instances"`
	Updated   time.Time `json:"updated"`
}

// Service keeps the subscriptions and sends the notifications.
type Service struct {
	// Subject is the VAPID contact (an https: or mailto: URL) the push services may use to reach the operator.
	Subject string
	// Client sends the messages; the default one refuses to connect to private addresses.
	Client *http.Client
	// Revoked (may be nil) tells whether the session was ended (signed out, evicted) or the user blocked: the
	// subscriptions of such a session are dropped instead of pushed to.
	Revoked func(session, user string) bool

	dir string // "" keeps everything in memory (tests)
	key *vapidKey

	mu   sync.Mutex
	subs map[string]Subscription // by endpoint
}

// Open loads (or creates) the VAPID key and the subscriptions in dir; "" keeps them in memory only.
// A file that cannot be read or written is logged and does not stop the server: push is then not persistent.
func Open(dir string) *Service {
	s := &Service{dir: dir, subs: map[string]Subscription{}, Client: newClient()}
	if dir != "" {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			log.Printf("push: %v (subscriptions are not kept)", err)
			s.dir = ""
		}
	}
	if s.dir != "" {
		if der, err := os.ReadFile(filepath.Join(s.dir, "vapid.key")); err == nil {
			if s.key, err = parseVAPIDKey(der); err != nil {
				log.Printf("push: vapid.key: %v (a new key is made, subscribers must subscribe again)", err)
			}
		}
		if b, err := os.ReadFile(filepath.Join(s.dir, "subscriptions.json")); err == nil {
			var list []Subscription
			if err := json.Unmarshal(b, &list); err != nil {
				log.Printf("push: subscriptions.json: %v", err)
			}
			for _, sub := range list {
				if time.Since(sub.Updated) < staleAfter {
					sort.Strings(sub.Instances) // Notify searches the list: it must be sorted whatever wrote the file
					s.subs[sub.Endpoint] = sub
				}
			}
		}
	}
	if s.key == nil {
		k, err := newVAPIDKey()
		if err != nil {
			log.Fatalf("push: %v", err)
		}
		s.key = k
		if s.dir != "" {
			if der, err := k.marshal(); err == nil {
				err = writeFile(filepath.Join(s.dir, "vapid.key"), der)
				if err != nil {
					log.Printf("push: %v (the key is lost at the next restart)", err)
				}
			}
		}
	}
	return s
}

// PublicKey is the applicationServerKey (base64url) the browsers subscribe with.
func (s *Service) PublicKey() string { return b64.EncodeToString(s.key.public()) }

// ValidEndpoint tells whether u may be the endpoint of a push service: https, a host name or a public address.
func ValidEndpoint(u string) bool {
	p, err := url.Parse(u)
	if err != nil || p.Scheme != "https" || p.Host == "" || p.User != nil || len(u) > 1024 {
		return false
	}
	if ip := net.ParseIP(p.Hostname()); ip != nil && !publicIP(ip) {
		return false
	}
	return true
}

// ErrInvalid is returned for a subscription that is malformed or over a limit.
var ErrInvalid = errors.New("push: invalid subscription")

// Set records the instances the browser of this subscription follows (replacing what it followed). An empty list
// removes the subscription.
func (s *Service) Set(user, session string, sub Subscription, instances []string) error {
	if len(instances) == 0 {
		return s.Remove(sub.Endpoint)
	}
	p, err := b64.DecodeString(sub.P256dh)
	a, err2 := b64.DecodeString(sub.Auth)
	if !ValidEndpoint(sub.Endpoint) || err != nil || err2 != nil || len(p) != 65 || len(a) != 16 || len(instances) > MaxInstances || user == "" {
		return ErrInvalid
	}
	for _, k := range instances {
		if !events.ValidKey(k) {
			return ErrInvalid
		}
	}
	sort.Strings(instances)
	instances = slices.Compact(instances)
	sub.User, sub.Session, sub.Instances, sub.Updated = user, session, instances, time.Now().UTC()
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.subs[sub.Endpoint]; !ok {
		own := 0
		for _, o := range s.subs {
			if o.User == user {
				own++
			}
		}
		if own >= MaxPerUser || len(s.subs) >= maxTotal {
			return ErrInvalid
		}
	}
	// an endpoint already known is replaced whoever registered it: the browser is used by this login now
	s.subs[sub.Endpoint] = sub
	return s.saveLocked()
}

// Remove forgets the subscription of that endpoint.
func (s *Service) Remove(endpoint string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.subs[endpoint]; !ok {
		return nil
	}
	delete(s.subs, endpoint)
	return s.saveLocked()
}

// RemoveSession forgets the subscriptions registered under that login session (it was signed out).
func (s *Service) RemoveSession(session string) error {
	if session == "" {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	n := len(s.subs)
	for e, sub := range s.subs {
		if sub.Session == session {
			delete(s.subs, e)
		}
	}
	if len(s.subs) == n {
		return nil
	}
	return s.saveLocked()
}

// ended tells whether the login session of the subscription was ended on purpose (signed out, evicted, blocked).
func (s *Service) ended(sub Subscription) bool {
	return s.Revoked != nil && s.Revoked(sub.Session, sub.User)
}

// Subscriptions returns a copy of the subscriptions (for tests and diagnostics: it carries the secret endpoints).
func (s *Service) Subscriptions() []Subscription {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]Subscription, 0, len(s.subs))
	for _, v := range s.subs {
		out = append(out, v)
	}
	return out
}

// SessionSummary is what a login session has registered: how many browsers follow instances under it, and how many
// instances in all (an instance followed by two browsers counts twice).
type SessionSummary struct{ Browsers, Instances int }

// BySession summarises the subscriptions per login session id (the secret endpoints stay inside).
func (s *Service) BySession() map[string]SessionSummary {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := map[string]SessionSummary{}
	for _, sub := range s.subs {
		if sub.Session == "" {
			continue
		}
		x := out[sub.Session]
		x.Browsers++
		x.Instances += len(sub.Instances)
		out[sub.Session] = x
	}
	return out
}

// Count is the number of subscribed browsers.
func (s *Service) Count() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.subs)
}

func (s *Service) saveLocked() error {
	if s.dir == "" {
		return nil
	}
	list := make([]Subscription, 0, len(s.subs))
	for _, v := range s.subs {
		list = append(list, v)
	}
	sort.Slice(list, func(i, j int) bool { return list[i].Endpoint < list[j].Endpoint })
	b, err := json.MarshalIndent(list, "", " ")
	if err != nil {
		return err
	}
	return writeFile(filepath.Join(s.dir, "subscriptions.json"), b)
}

// writeFile replaces path atomically, readable by the service user only.
func writeFile(path string, data []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	_, werr := tmp.Write(data)
	cerr := tmp.Close()
	if werr != nil || cerr != nil {
		_ = os.Remove(name)
		return errors.Join(werr, cerr)
	}
	if err := os.Chmod(name, 0o600); err != nil {
		_ = os.Remove(name)
		return err
	}
	if err := os.Rename(name, path); err != nil {
		_ = os.Remove(name)
		return err
	}
	return nil
}

// message is what the service worker receives (sw.js shows it).
type message struct {
	Title string `json:"title"`
	Body  string `json:"body"`
	Key   string `json:"key"`
	URL   string `json:"url"`
}

// Run sends a notification for every deployment published on hub, to the browsers that follow that instance, until
// ctx ends. The refresh of the branches is not a deployment.
func (s *Service) Run(ctx context.Context, hub *events.Hub) {
	ch, cancel := hub.Subscribe()
	defer cancel()
	for {
		select {
		case <-ctx.Done():
			return
		case e := <-ch:
			// in the background: a slow push service must not make this loop miss the next events (the hub drops
			// what a subscriber does not read in time)
			if e.Kind == "" {
				go s.Notify(ctx, e)
			}
		}
	}
}

// Notify sends the notification of one deployment to the browsers that follow its instance.
func (s *Service) Notify(ctx context.Context, e events.Event) {
	// The person knows the instance by the address it answers on (DEPLOYMENT_EXT_HOST, the external FQDN), not by its key
	// (which only identifies it internally and stays the notification's tag); the key stands in when the host is unknown
	name := e.Host
	if name == "" {
		name = e.Key
	}
	payload, _ := json.Marshal(message{Title: name + " has been deployed", Body: "Deployed and started", Key: e.Key, URL: "/"})
	var targets []Subscription
	s.mu.Lock()
	for _, sub := range s.subs {
		i := sort.SearchStrings(sub.Instances, e.Key)
		if i < len(sub.Instances) && sub.Instances[i] == e.Key {
			targets = append(targets, sub)
		}
	}
	s.mu.Unlock()
	// the sessions that were ended are forgotten, not pushed to (a browser registers again when its person signs in)
	live := targets[:0]
	for _, sub := range targets {
		if s.ended(sub) {
			if err := s.Remove(sub.Endpoint); err != nil {
				log.Printf("push: %v", err)
			}
			continue
		}
		live = append(live, sub)
	}
	targets = live
	sem := make(chan struct{}, sendWorkers)
	var wg sync.WaitGroup
	for _, sub := range targets {
		sem <- struct{}{}
		wg.Add(1)
		go func() {
			defer func() { <-sem; wg.Done() }()
			if err := s.send(ctx, sub, payload); err != nil {
				log.Printf("push: %s: %v", host(sub.Endpoint), err)
			}
		}()
	}
	wg.Wait()
}

func host(endpoint string) string {
	if u, err := url.Parse(endpoint); err == nil {
		return u.Host
	}
	return "?"
}

func (s *Service) send(ctx context.Context, sub Subscription, payload []byte) error {
	p, _ := b64.DecodeString(sub.P256dh)
	a, _ := b64.DecodeString(sub.Auth)
	body, err := Encrypt(payload, p, a)
	if err != nil {
		return err
	}
	u, err := url.Parse(sub.Endpoint)
	if err != nil {
		return err
	}
	subject := s.Subject
	if subject == "" {
		subject = "https://example.org"
	}
	authz, err := s.key.authorization(u.Scheme+"://"+u.Host, subject, time.Now())
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, sub.Endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", authz)
	req.Header.Set("Content-Encoding", "aes128gcm")
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("TTL", fmt.Sprint(messageTTL))
	resp, err := s.Client.Do(req)
	if err != nil {
		// not the *url.Error as it is: it carries the whole endpoint, a secret that grants the right to push to the browser
		var ue *url.Error
		if errors.As(err, &ue) {
			err = ue.Err
		}
		return err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4096))
	switch {
	case resp.StatusCode >= 200 && resp.StatusCode < 300:
		return nil
	case resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusGone:
		// the browser unsubscribed or the subscription expired
		return errors.Join(fmt.Errorf("gone (%d), subscription removed", resp.StatusCode), s.Remove(sub.Endpoint))
	}
	return fmt.Errorf("push service answered %d", resp.StatusCode)
}

// newClient is the client that sends the messages: no redirect is followed (a push service answers directly), and
// only public addresses are reached.
func newClient() *http.Client {
	return &http.Client{
		Timeout:       sendTimeout,
		Transport:     publicOnlyTransport(),
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
}

// cgnat is the shared address space (RFC 6598) of carrier networks: not public, not marked private by net.
var cgnat = &net.IPNet{IP: net.IPv4(100, 64, 0, 0), Mask: net.CIDRMask(10, 32)}

// publicIP is false for the addresses a push service never has: loopback, private, link-local, unspecified.
func publicIP(ip net.IP) bool {
	return ip.IsGlobalUnicast() && !ip.IsPrivate() && !ip.IsLoopback() && !ip.IsLinkLocalUnicast() && !cgnat.Contains(ip)
}

// publicOnlyTransport refuses to connect to a non-public address: the endpoint is chosen by the visitor, and the
// server must not be made to call its own network. The check is on the address actually dialed (after the DNS lookup).
func publicOnlyTransport() *http.Transport {
	d := &net.Dialer{Timeout: sendTimeout, Control: func(_, address string, _ syscall.RawConn) error {
		h, _, err := net.SplitHostPort(address)
		if err != nil {
			return err
		}
		if ip := net.ParseIP(h); ip == nil || !publicIP(ip) {
			return errors.New("push: refusing to connect to a non-public address")
		}
		return nil
	}}
	return &http.Transport{DialContext: d.DialContext, TLSHandshakeTimeout: sendTimeout, ResponseHeaderTimeout: sendTimeout, IdleConnTimeout: 90 * time.Second}
}
