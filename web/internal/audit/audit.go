// Package audit is the audit log of the administrative actions done from the dashboard. One JSON object per
// line in $ADT_DATA/var/audit/audit.log, rotated at 5MB (audit.log -> audit.log.1, one generation kept).
package audit

import (
	"bufio"
	"bytes"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/exoplatform/adt/web/internal/auth"
)

const maxSize = 5 * 1024 * 1024

// Log is the audit log of one ADT_DATA.
type Log struct {
	dir string
	mu  sync.Mutex
}

var (
	cacheMu sync.Mutex
	cache   = map[string]*Log{}
)

// For returns the shared Log of a data directory (one per process, so writes are serialised).
func For(dataDir string) *Log {
	cacheMu.Lock()
	defer cacheMu.Unlock()
	if l, ok := cache[dataDir]; ok {
		return l
	}
	l := New(dataDir)
	cache[dataDir] = l
	return l
}

// New builds a Log writing under dataDir/var/audit.
func New(dataDir string) *Log { return &Log{dir: filepath.Join(dataDir, "var", "audit")} }

// Dir is the directory holding the audit logs.
func (l *Log) Dir() string { return l.dir }

// Entry is one line of the log. Detail keeps the exact JSON written (key order preserved).
type Entry struct {
	TS     int64           `json:"ts"`
	User   string          `json:"user"`
	IP     string          `json:"ip"`
	Action string          `json:"action"`
	Detail json.RawMessage `json:"detail"`
}

// DetailString is the compact JSON of the entry detail, "[]" when empty.
func (e Entry) DetailString() string {
	var b bytes.Buffer
	if len(e.Detail) == 0 || json.Compact(&b, e.Detail) != nil {
		return "[]"
	}
	if s := b.String(); s != "null" && s != "{}" {
		return s
	}
	return "[]"
}

// Actor is the login doing the request, "-" when unknown.
func Actor(r *http.Request) string {
	if r != nil {
		if u := r.Header.Get(auth.HeaderUser); u != "" {
			return u
		}
		if u := auth.From(r).User; u != "" {
			return u
		}
	}
	return "-"
}

// ClientIP is the address of the client: behind Apache (unix socket) the last X-Forwarded-For entry, which
// Apache's mod_proxy appended itself; otherwise the peer address.
func ClientIP(r *http.Request) string {
	if r == nil {
		return ""
	}
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[len(parts)-1])
	}
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		return host
	}
	return r.RemoteAddr
}

// Add appends an entry, never fails the request. detail is a list of
// alternating keys and values, kept in that order: Add(r, "user.block", "target", user, "minutes", 30).
func (l *Log) Add(r *http.Request, action string, detail ...any) {
	if err := os.MkdirAll(l.dir, 0o755); err != nil {
		return
	}
	var d bytes.Buffer
	d.WriteByte('{')
	for i := 0; i+1 < len(detail); i += 2 {
		k, _ := detail[i].(string)
		if i > 0 {
			d.WriteByte(',')
		}
		kb, _ := marshal(k)
		vb, _ := marshal(detail[i+1])
		d.Write(bytes.TrimRight(kb, "\n"))
		d.WriteByte(':')
		d.Write(bytes.TrimRight(vb, "\n"))
	}
	d.WriteByte('}')
	detailJSON := d.String()
	if detailJSON == "{}" {
		detailJSON = "[]" // an empty detail is logged as an empty array
	}
	var line bytes.Buffer
	line.WriteString(`{"ts":`)
	ts, _ := marshal(time.Now().Unix())
	line.Write(bytes.TrimRight(ts, "\n"))
	for _, kv := range [][2]string{{"user", Actor(r)}, {"ip", ClientIP(r)}, {"action", action}} {
		b, _ := marshal(kv[1])
		line.WriteString(`,"` + kv[0] + `":`)
		line.Write(bytes.TrimRight(b, "\n"))
	}
	line.WriteString(`,"detail":` + detailJSON + "}\n")

	l.mu.Lock()
	defer l.mu.Unlock()
	file := filepath.Join(l.dir, "audit.log")
	if st, err := os.Stat(file); err == nil && st.Size() > maxSize {
		_ = os.Rename(file, file+".1")
	}
	f, err := os.OpenFile(file, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.Write(line.Bytes())
}

// marshal is a JSON encoder with unescaped slashes and unicode (and no HTML escaping).
func marshal(v any) ([]byte, error) {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	err := enc.Encode(v)
	return b.Bytes(), err
}

// Filters of Read: Action is a prefix match, User an exact match, Q a case-insensitive substring of the raw line.
type Filters struct{ Action, User, Q string }

// Read returns the latest entries first (audit.log then audit.log.1).
func (l *Log) Read(limit int, f Filters) []Entry {
	var out []Entry
	q := strings.ToLower(f.Q)
	for _, name := range []string{"audit.log", "audit.log.1"} {
		file, err := os.Open(filepath.Join(l.dir, name))
		if err != nil {
			continue
		}
		var lines []string
		sc := bufio.NewScanner(file)
		sc.Buffer(make([]byte, 1<<20), 16<<20)
		for sc.Scan() {
			if t := sc.Text(); t != "" {
				lines = append(lines, t)
			}
		}
		_ = file.Close()
		for i := len(lines) - 1; i >= 0; i-- {
			var e Entry
			if json.Unmarshal([]byte(lines[i]), &e) != nil {
				continue
			}
			if f.Action != "" && !strings.HasPrefix(e.Action, f.Action) {
				continue
			}
			if f.User != "" && e.User != f.User {
				continue
			}
			if q != "" && !strings.Contains(strings.ToLower(lines[i]), q) {
				continue
			}
			out = append(out, e)
			if len(out) >= limit {
				return out
			}
		}
	}
	return out
}
