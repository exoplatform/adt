// Package sessions tracks the login sessions and enforces their eviction.
//
// Login sessions are stateless encrypted cookies (mod_session_cookie), so Apache keeps no list of them. Each
// dashboard request records its session here (one JSON file per session under $ADT_DATA/var/sessions, keyed
// by sha1 of the raw session cookie). Evicting a session adds that same sha1 to revoked.txt, which Apache
// reads on every request (Require expr + file(), see frontend.include.j2) to reject the cookie. Blocking a
// user adds sha1(lowercase login) to the same file.
//
// The application never sees the decrypted session payload: it works from the identity headers (package
// auth) and the session hash (ID). The record format is shared so /debug-sessions shows every record.
package sessions

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/exoplatform/adt/web/internal/audit"
	"github.com/exoplatform/adt/web/internal/auth"
)

// trackInterval is the throttle of Track: at most one write every 30s per session.
const trackInterval = 30

// Session is a tracked login session (one JSON file).
type Session struct {
	ID        string `json:"id"`
	FirstSeen int64  `json:"first_seen"`
	Evicted   bool   `json:"evicted"`
	User      string `json:"user"`
	Name      string `json:"name"`
	IP        string `json:"ip"`
	UA        string `json:"ua"`
	Expiry    int64  `json:"expiry"` // unix seconds
	LastSeen  int64  `json:"last_seen"`
	EvictedAt int64  `json:"evicted_at,omitempty"`
	EvictedBy string `json:"evicted_by,omitempty"`
}

// Block is an active login block (one JSON file per blocked user).
type Block struct {
	Hash  string `json:"hash"`
	User  string `json:"user"`
	Until int64  `json:"until"` // unix seconds
	By    string `json:"by"`
	At    int64  `json:"at"`
}

// Store is the session store of one ADT_DATA.
type Store struct {
	dir   string
	audit *audit.Log

	mu       sync.Mutex
	lastSeen map[string]int64 // in-memory throttle of Track
	once     sync.Once
	secret   []byte
}

var (
	cacheMu sync.Mutex
	cache   = map[string]*Store{}
)

// For returns the shared Store of a data directory (one per process).
func For(dataDir string) *Store {
	cacheMu.Lock()
	defer cacheMu.Unlock()
	if s, ok := cache[dataDir]; ok {
		return s
	}
	s := New(dataDir)
	cache[dataDir] = s
	return s
}

// New builds a Store on dataDir/var/sessions; it audits through audit.For(dataDir).
func New(dataDir string) *Store {
	return &Store{dir: filepath.Join(dataDir, "var", "sessions"), audit: audit.For(dataDir), lastSeen: map[string]int64{}}
}

// Dir is the sessions directory.
func (s *Store) Dir() string { return s.dir }

func (s *Store) blockedDir() string  { return filepath.Join(s.dir, "blocked") }
func (s *Store) revokedFile() string { return filepath.Join(s.dir, "revoked.txt") }

var (
	cookieRe = regexp.MustCompile(`(?:^|; ?)adt_session=([^;]+)`)
	hexIDRe  = regexp.MustCompile(`^[0-9a-f]{40}$`)
)

// CookieValue returns the raw (still encrypted) adt_session cookie as sent in the Cookie
// header, or "". Prefer ID(): Apache can hand over the hash and strip the cookie.
func CookieValue(r *http.Request) string {
	m := cookieRe.FindStringSubmatch(strings.Join(r.Header.Values("Cookie"), "; "))
	if m == nil {
		return ""
	}
	return m[1]
}

func sha1hex(s string) string { h := sha1.Sum([]byte(s)); return hex.EncodeToString(h[:]) }

// ID returns the identifier of the session of the request (what Apache hashes in its
// revocation check) or "". It is the X-Session-Hash header Apache sets, else sha1 of the adt_session cookie.
func ID(r *http.Request) string {
	if h := strings.ToLower(r.Header.Get(auth.HeaderSession)); hexIDRe.MatchString(h) {
		return h
	}
	if raw := CookieValue(r); raw != "" {
		return sha1hex(raw)
	}
	return ""
}

// UserHash is the key of a user in the blocks and in revoked.txt (sha1 of the lowercase login;
// Apache computes the same with sha1(tolower(REMOTE_USER))).
func UserHash(user string) string { return sha1hex(strings.ToLower(user)) }

func (s *Store) revokedLines() map[string]bool {
	b, err := os.ReadFile(s.revokedFile())
	if err != nil {
		return nil
	}
	set := map[string]bool{}
	for _, l := range strings.Split(string(b), "\n") {
		if l = strings.TrimSpace(l); l != "" {
			set[l] = true
		}
	}
	return set
}

// IsRevoked reports whether the request carries an evicted session.
func (s *Store) IsRevoked(r *http.Request) bool {
	id := ID(r)
	return id != "" && s.revokedLines()[id]
}

// IsUserListed reports whether revoked.txt currently lists the user (a block, possibly a stale one).
func (s *Store) IsUserListed(user string) bool { return s.revokedLines()[UserHash(user)] }

// secretKey is the HMAC key of the CSRF tokens: persisted in var/sessions/csrf.key (0600) so tokens survive
// a restart, random per process when the directory is not writable.
func (s *Store) secretKey() []byte {
	s.once.Do(func() {
		file := filepath.Join(s.dir, "csrf.key")
		if b, err := os.ReadFile(file); err == nil && len(b) >= 32 {
			s.secret = b
			return
		}
		key := make([]byte, 32)
		if _, err := rand.Read(key); err != nil {
			panic(err)
		}
		s.secret = key
		if f, err := os.OpenFile(file, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600); err == nil {
			_, _ = f.Write(key)
			_ = f.Close()
		} else if b, err := os.ReadFile(file); err == nil && len(b) >= 32 {
			s.secret = b // another process won the race
		}
	})
	return s.secret
}

func csrfSubject(r *http.Request) string {
	if id := ID(r); id != "" {
		return "session:" + id
	}
	if u := auth.From(r).User; u != "" { // dev mode: no cookie
		return "user:" + u
	}
	return ""
}

// CSRFToken is the HMAC-SHA256 over the session id with the server secret
// (the secret session payload is not received by the app). "" when there is no session.
func (s *Store) CSRFToken(r *http.Request) string {
	subj := csrfSubject(r)
	if subj == "" {
		return ""
	}
	m := hmac.New(sha256.New, s.secretKey())
	m.Write([]byte("evict-session\x00" + subj))
	return hex.EncodeToString(m.Sum(nil))
}

// CheckCSRF compares a submitted token in constant time; an empty token never matches.
func (s *Store) CheckCSRF(r *http.Request, token string) bool {
	want := s.CSRFToken(r)
	return want != "" && token != "" && subtle.ConstantTimeCompare([]byte(want), []byte(token)) == 1
}

// writeJSON writes v atomically (temp file + rename), 0644 so Apache and the other user can read it.
func writeFileAtomic(path string, data []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	_, werr := tmp.Write(data)
	cerr := tmp.Close()
	if werr != nil || cerr != nil {
		_ = os.Remove(name)
		return fmt.Errorf("write %s: %v %v", path, werr, cerr)
	}
	_ = os.Chmod(name, 0o644)
	if err := os.Rename(name, path); err != nil {
		_ = os.Remove(name)
		return err
	}
	return nil
}

func writeJSON(path string, v any) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	return writeFileAtomic(path, b)
}

func readSession(file string) (Session, bool) {
	b, err := os.ReadFile(file)
	if err != nil {
		return Session{}, false
	}
	var rec Session
	if json.Unmarshal(b, &rec) != nil || rec.ID == "" {
		return Session{}, false
	}
	return rec, true
}

// Track records the session of the request (throttled to one write per 30s). It does
// nothing without a session, an identity or an expiry, when the sessions directory does not exist, and
// never fails the page.
func (s *Store) Track(r *http.Request, id auth.Identity) {
	sid := ID(r)
	if sid == "" || id.User == "" || id.Expiry.IsZero() {
		return
	}
	if st, err := os.Stat(s.dir); err != nil || !st.IsDir() {
		return
	}
	now := time.Now().Unix()
	s.mu.Lock()
	defer s.mu.Unlock()
	if last, ok := s.lastSeen[sid]; ok && last > now-trackInterval {
		return
	}
	file := filepath.Join(s.dir, sid+".json")
	rec, ok := readSession(file)
	if !ok {
		rec = Session{ID: sid, FirstSeen: now}
	}
	if rec.Evicted || rec.LastSeen > now-trackInterval {
		s.lastSeen[sid] = rec.LastSeen
		return
	}
	ua := r.UserAgent()
	if len(ua) > 200 {
		ua = ua[:200]
	}
	name := id.Name
	if name == "" {
		name = id.User
	}
	rec.User, rec.Name, rec.IP, rec.UA = id.User, name, audit.ClientIP(r), ua
	rec.Expiry, rec.LastSeen = id.Expiry.Unix(), now
	if writeJSON(file, rec) != nil {
		return
	}
	if len(s.lastSeen) > 10000 {
		s.lastSeen = map[string]int64{}
	}
	s.lastSeen[sid] = now
}

// List returns the tracked sessions that have not expired, newest activity first. Expired ones
// are pruned. revoked.txt is regenerated on every call.
func (s *Store) List() []Session {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.listLocked()
}

func (s *Store) listLocked() []Session {
	var out []Session
	now := time.Now().Unix()
	files, _ := filepath.Glob(filepath.Join(s.dir, "*.json"))
	for _, f := range files {
		rec, ok := readSession(f)
		if !ok || rec.Expiry <= now {
			_ = os.Remove(f)
			continue
		}
		out = append(out, rec)
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].LastSeen > out[j].LastSeen })
	s.rewriteRevokedLocked(out)
	return out
}

// rewriteRevokedLocked regenerates revoked.txt = evicted live sessions + blocked users.
func (s *Store) rewriteRevokedLocked(sessions []Session) {
	var b strings.Builder
	for _, x := range sessions {
		if x.Evicted {
			b.WriteString(x.ID + "\n")
		}
	}
	for _, blk := range s.listBlockedLocked() {
		b.WriteString(blk.Hash + "\n")
	}
	file := s.revokedFile()
	if old, err := os.ReadFile(file); err == nil && string(old) == b.String() {
		return
	}
	_ = writeFileAtomic(file, []byte(b.String()))
}

// Evict flags one tracked session as evicted (by the user of r). False if not found.
func (s *Store) Evict(r *http.Request, id string) bool {
	if !hexIDRe.MatchString(id) {
		return false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	file := filepath.Join(s.dir, id+".json")
	rec, ok := readSession(file)
	if !ok {
		return false
	}
	rec.Evicted, rec.EvictedAt, rec.EvictedBy = true, time.Now().Unix(), audit.Actor(r)
	if writeJSON(file, rec) != nil {
		return false
	}
	s.listLocked() // regenerates revoked.txt
	s.audit.Add(r, "session.evict", "target", rec.User, "session", id[:8])
	return true
}

func (s *Store) evictWhere(r *http.Request, match func(Session) bool) int {
	n := 0
	for _, x := range s.listLocked() {
		if !x.Evicted && match(x) {
			x.Evicted, x.EvictedAt, x.EvictedBy = true, time.Now().Unix(), audit.Actor(r)
			if writeJSON(filepath.Join(s.dir, x.ID+".json"), x) == nil {
				n++
			}
		}
	}
	s.listLocked() // regenerates revoked.txt
	return n
}

// EvictAll evicts every tracked, not yet evicted session except exceptID.
func (s *Store) EvictAll(r *http.Request, exceptID string) int {
	s.mu.Lock()
	n := s.evictWhere(r, func(x Session) bool { return x.ID != exceptID })
	s.mu.Unlock()
	s.audit.Add(r, "session.evict-all", "count", n)
	return n
}

// EvictUser evicts all the sessions of a user (case-insensitive) except exceptID.
func (s *Store) EvictUser(r *http.Request, user, exceptID string) int {
	s.mu.Lock()
	n := s.evictWhere(r, func(x Session) bool { return strings.EqualFold(x.User, user) && x.ID != exceptID })
	s.mu.Unlock()
	s.audit.Add(r, "session.evict-user", "target", user, "count", n)
	return n
}

// ListBlocked returns the active login blocks, soonest to expire first. Expired ones are removed.
func (s *Store) ListBlocked() []Block {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.listBlockedLocked()
}

func (s *Store) listBlockedLocked() []Block {
	var out []Block
	files, _ := filepath.Glob(filepath.Join(s.blockedDir(), "*.json"))
	for _, f := range files {
		var b Block
		data, err := os.ReadFile(f)
		if err != nil || json.Unmarshal(data, &b) != nil || b.Until <= time.Now().Unix() {
			_ = os.Remove(f)
			continue
		}
		out = append(out, b)
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].Until < out[j].Until })
	return out
}

// UserBlock returns the active block of a user (case-insensitive), or nil.
func (s *Store) UserBlock(user string) *Block {
	h := UserHash(user)
	for _, b := range s.ListBlocked() {
		if b.Hash == h {
			b := b
			return &b
		}
	}
	return nil
}

// BlockUser refuses the login of a user for minutes (at least 1) and evicts their sessions
// except exceptID.
func (s *Store) BlockUser(r *http.Request, user string, minutes int, exceptID string) {
	s.mu.Lock()
	_ = os.MkdirAll(s.blockedDir(), 0o755)
	now := time.Now().Unix()
	b := Block{Hash: UserHash(user), User: user, Until: now + int64(max(1, minutes))*60, By: audit.Actor(r), At: now}
	_ = writeJSON(filepath.Join(s.blockedDir(), b.Hash+".json"), b)
	s.evictWhere(r, func(x Session) bool { return strings.EqualFold(x.User, user) && x.ID != exceptID }) // also rewrites revoked.txt
	s.mu.Unlock()
	s.audit.Add(r, "user.block", "target", user, "minutes", minutes)
}

// UnblockUser removes a block by its hash. False if not found.
func (s *Store) UnblockUser(r *http.Request, hash string) bool {
	if !hexIDRe.MatchString(hash) {
		return false
	}
	s.mu.Lock()
	file := filepath.Join(s.blockedDir(), hash+".json")
	var b Block
	data, err := os.ReadFile(file)
	if err != nil || json.Unmarshal(data, &b) != nil {
		s.mu.Unlock()
		return false
	}
	_ = os.Remove(file)
	s.listLocked() // regenerates revoked.txt
	s.mu.Unlock()
	s.audit.Add(r, "user.unblock", "target", b.User)
	return true
}

// DurationLabel formats a duration as "2h 05m" / "3d 4h".
func DurationLabel(seconds int64) string {
	seconds = max(0, seconds)
	d, h, m := seconds/86400, seconds%86400/3600, seconds%3600/60
	if d > 0 {
		return fmt.Sprintf("%dd %dh", d, h)
	}
	return fmt.Sprintf("%dh %02dm", h, m)
}
