// Package stats is the live resource usage of the acceptance servers.
//
// Everything is read from /proc and statfs(2); nothing is spawned. The JSON shapes are exchanged with the
// other acceptance servers, which fetch /rest/local-stats.php from this one and the other way round.
package stats

import (
	"bytes"
	"context"
	"encoding/json"
	"math"
	"net/url"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/httpx"
	"github.com/exoplatform/adt/web/internal/instances"
)

// F64 is a float printed in the shortest form that round-trips: 4.0 prints as 4.
type F64 float64

// MarshalJSON implements json.Marshaler.
func (f F64) MarshalJSON() ([]byte, error) {
	v := float64(f)
	if math.Abs(v) < 1e15 {
		return []byte(strconv.FormatFloat(v, 'f', -1, 64)), nil
	}
	return []byte(strconv.FormatFloat(v, 'g', -1, 64)), nil
}

// Mem is the "mem" entry (kB).
type Mem struct {
	TotalKB     int64 `json:"total_kb"`
	UsedKB      int64 `json:"used_kb"`
	SwapTotalKB int64 `json:"swap_total_kb"`
	SwapUsedKB  int64 `json:"swap_used_kb"`
}

// CPU is the "cpu" entry; unknown values are null.
type CPU struct {
	Model   *string `json:"model"`
	Threads *int    `json:"threads"`
	Cores   *int    `json:"cores"`
}

// Disk is the "disk" entry (bytes).
type Disk struct {
	TotalB F64 `json:"total_b"`
	UsedB  F64 `json:"used_b"`
}

// JVM is one running instance JVM.
type JVM struct {
	Key   string `json:"key"`
	Label string `json:"label"`
	RSSKB int64  `json:"rss_kb"`
	XmxGB *F64   `json:"xmx_gb"`
}

// JVMs is the "jvm" entry.
type JVMs struct {
	Running  int   `json:"running"`
	RSSKB    int64 `json:"rss_kb"`
	XmxGB    any   `json:"xmx_gb"` // int 0 when no size is known (array_sum of nothing), else F64
	Readable bool  `json:"readable"`
	List     []JVM `json:"list"`
}

// Local is what /rest/local-stats.php answers. Key order is part of the JSON exchanged with the other acceptance servers.
type Local struct {
	Host    string `json:"host"`
	Time    int64  `json:"time"`
	Mem     *Mem   `json:"mem"`
	CPU     CPU    `json:"cpu"`
	Load    []F64  `json:"load"`
	UptimeS *int64 `json:"uptime_s"`
	Disk    *Disk  `json:"disk"`
	JVM     JVMs   `json:"jvm"`
}

var jvmSizeRe = regexp.MustCompile(`^\s*([0-9.]+)\s*([gGmM])\s*$`)

// JVMSizeToGB converts "4g" -> 4, "512m" -> 0.5; ok is false when the unit is not managed.
func JVMSizeToGB(size string) (gb float64, ok bool) {
	m := jvmSizeRe.FindStringSubmatch(strings.TrimSuffix(size, "\n"))
	if m == nil {
		return 0, false
	}
	v := PHPFloat(m[1])
	if strings.EqualFold(m[2], "g") {
		return v, true
	}
	return v / 1024, true
}

// PHPFloat parses the longest numeric prefix of s as a float, 0 when none.
func PHPFloat(s string) float64 {
	s = strings.TrimLeft(s, " \t\n\r\v\f")
	end := 0
	for end < len(s) && strings.IndexByte("0123456789.eE+-", s[end]) >= 0 {
		end++ // ParseFloat alone would also accept "inf", "nan", hex floats
	}
	s = s[:end]
	for n := len(s); n > 0; n-- {
		if f, err := strconv.ParseFloat(s[:n], 64); err == nil {
			return f
		}
	}
	return 0
}

// phpInt parses leading blanks, an optional sign and digits of s, 0 when none.
func phpInt(s string) int64 {
	s = strings.TrimLeft(s, " \t\n\r\v\f")
	end := 0
	if end < len(s) && (s[end] == '+' || s[end] == '-') {
		end++
	}
	for end < len(s) && s[end] >= '0' && s[end] <= '9' {
		end++
	}
	n, _ := strconv.ParseInt(s[:end], 10, 64)
	return n
}

var (
	memLineRe  = regexp.MustCompile(`^(\w+):\s+(\d+)`)
	modelRe    = regexp.MustCompile(`(?m)^model name\s*:\s*(.+)$`)
	socketRe   = regexp.MustCompile(`(?m)^physical id\s*:\s*(\d+)$`)
	coresRe    = regexp.MustCompile(`(?m)^cpu cores\s*:\s*(\d+)$`)
	procRe     = regexp.MustCompile(`(?m)^processor\s*:`)
	spacesRe   = regexp.MustCompile(`\s+`)
	vmRSSRe    = regexp.MustCompile(`(?m)^VmRSS:\s+(\d+)\s+kB`)
	procPrefix = "/proc"
)

// ParseMem is the /proc/meminfo part: nil when MemTotal or MemAvailable is missing.
func ParseMem(meminfo string) *Mem {
	m := map[string]int64{}
	for _, line := range strings.Split(meminfo, "\n") {
		if g := memLineRe.FindStringSubmatch(line); g != nil {
			m[g[1]], _ = strconv.ParseInt(g[2], 10, 64)
		}
	}
	total, ok1 := m["MemTotal"]
	avail, ok2 := m["MemAvailable"]
	if !ok1 || !ok2 {
		return nil
	}
	return &Mem{TotalKB: total, UsedKB: total - avail, SwapTotalKB: m["SwapTotal"], SwapUsedKB: m["SwapTotal"] - m["SwapFree"]}
}

// ParseCPU is the /proc/cpuinfo part.
func ParseCPU(cpuinfo string) CPU {
	var c CPU
	if g := modelRe.FindStringSubmatch(cpuinfo); g != nil {
		s := strings.TrimSpace(spacesRe.ReplaceAllString(g[1], " "))
		c.Model = &s
	}
	if n := len(procRe.FindAllString(cpuinfo, -1)); n > 0 {
		c.Threads = &n
	}
	if g := coresRe.FindStringSubmatch(cpuinfo); g != nil {
		sockets := map[string]bool{}
		for _, s := range socketRe.FindAllStringSubmatch(cpuinfo, -1) {
			sockets[s[1]] = true
		}
		n, _ := strconv.Atoi(g[1])
		n *= max(1, len(sockets))
		c.Cores = &n
	}
	return c
}

// ParseLoad is the /proc/loadavg part: the three averages, nil when fewer than three fields.
func ParseLoad(loadavg string) []F64 {
	f := strings.Split(loadavg, " ")
	if len(f) < 3 {
		return nil
	}
	out := make([]F64, 3)
	for i := range out {
		out[i] = F64(PHPFloat(f[i]))
	}
	return out
}

// ParseUptime is the /proc/uptime part ((int) of the first number), nil when empty.
func ParseUptime(uptime string) *int64 {
	if uptime == "" {
		return nil
	}
	n := phpInt(uptime)
	return &n
}

// ParseVmRSS extracts VmRSS (kB) from /proc/PID/status; 0 when absent.
func ParseVmRSS(status string) int64 {
	if g := vmRSSRe.FindStringSubmatch(status); g != nil {
		n, _ := strconv.ParseInt(g[1], 10, 64)
		return n
	}
	return 0
}

func readFile(p string) (string, bool) {
	b, err := os.ReadFile(p)
	return string(b), err == nil
}

// DiskUsage is disk_total_space / disk_free_space of dir (free = space available to unprivileged users).
func DiskUsage(dir string) *Disk {
	var st syscall.Statfs_t
	if syscall.Statfs(dir, &st) != nil {
		return nil
	}
	total := float64(st.Blocks) * float64(st.Frsize)
	free := float64(st.Bavail) * float64(st.Frsize)
	if total == 0 {
		return nil
	}
	return &Disk{TotalB: F64(total), UsedB: F64(total - free)}
}

// ComputeLocal computes the stats of this server. host is SERVER_NAME, dataDir ADT_DATA ("" means "/"), insts the
// instances of this server, flattened.
func ComputeLocal(host, dataDir string, insts []instances.Instance) *Local {
	s := &Local{Host: host, Time: time.Now().Unix()}
	if t, ok := readFile(procPrefix + "/meminfo"); ok {
		s.Mem = ParseMem(t)
	}
	cpuinfo, _ := readFile(procPrefix + "/cpuinfo")
	s.CPU = ParseCPU(cpuinfo)
	if t, ok := readFile(procPrefix + "/loadavg"); ok {
		s.Load = ParseLoad(t)
	}
	if t, ok := readFile(procPrefix + "/uptime"); ok {
		s.UptimeS = ParseUptime(t)
	}
	if dataDir == "" {
		dataDir = "/"
	}
	s.Disk = DiskUsage(dataDir)

	jvms := []JVM{}
	readable := true
	for _, d := range insts {
		pidFile := d.Str("DEPLOYMENT_PID_FILE")
		if pidFile == "" || pidFile == "0" {
			continue
		}
		raw, err := os.ReadFile(pidFile)
		if err != nil {
			continue
		}
		pid := phpInt(strings.TrimSpace(string(raw)))
		if pid <= 0 {
			continue
		}
		dir := procPrefix + "/" + strconv.FormatInt(pid, 10)
		if _, err := os.Stat(dir); err != nil {
			continue
		}
		status, err := os.ReadFile(dir + "/status")
		if err != nil {
			readable = false
			continue
		}
		label := d.Str("PRODUCT_NAME")
		if d.Truthy("PRODUCT_DESCRIPTION") {
			label = d.Str("PRODUCT_DESCRIPTION")
		}
		if d.Truthy("INSTANCE_ID") {
			label += " (" + d.Str("INSTANCE_ID") + ")"
		}
		j := JVM{Key: d.Str("INSTANCE_KEY"), Label: label, RSSKB: ParseVmRSS(string(status))}
		if gb, ok := JVMSizeToGB(d.Str("DEPLOYMENT_JVM_SIZE_MAX")); ok {
			f := F64(gb)
			j.XmxGB = &f
		}
		jvms = append(jvms, j)
	}
	sort.SliceStable(jvms, func(a, b int) bool { return jvms[a].RSSKB > jvms[b].RSSKB })
	var rss int64
	var xmx float64
	anyXmx := false
	for _, j := range jvms {
		rss += j.RSSKB
		if j.XmxGB != nil {
			xmx += float64(*j.XmxGB)
			anyXmx = true
		}
	}
	s.JVM = JVMs{Running: len(jvms), RSSKB: rss, Readable: readable, List: jvms, XmxGB: 0}
	if anyXmx {
		s.JVM.XmxGB = F64(xmx)
	}
	return s
}

// Entry is one server of the global answer: the server's own JSON, or an error stub.
type Entry struct {
	Host string
	JSON json.RawMessage
}

// Global is the keyed-by-host answer of the servers' stats, in insertion order.
type Global []Entry

// MarshalJSON prints a JSON object keyed by host ([] when empty).
func (g Global) MarshalJSON() ([]byte, error) {
	if len(g) == 0 {
		return []byte("[]"), nil
	}
	var b bytes.Buffer
	b.WriteByte('{')
	seen := map[string]int{}
	n := 0
	// a duplicated host overwrites the earlier value but keeps its position
	vals := map[string]json.RawMessage{}
	var order []string
	for _, e := range g {
		if _, ok := seen[e.Host]; !ok {
			seen[e.Host] = n
			n++
			order = append(order, e.Host)
		}
		vals[e.Host] = e.JSON
	}
	for i, h := range order {
		if i > 0 {
			b.WriteByte(',')
		}
		k, _ := marshal(h)
		b.Write(bytes.TrimSpace(k))
		b.WriteByte(':')
		b.Write(vals[h])
	}
	b.WriteByte('}')
	return b.Bytes(), nil
}

func marshal(v any) ([]byte, error) {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return nil, err
	}
	return bytes.TrimRight(b.Bytes(), "\n"), nil
}

// Marshal encodes v like json_encode for the REST answers (no HTML escaping, no trailing newline).
func Marshal(v any) ([]byte, error) { return marshal(v) }

const (
	cacheKey   = "all_server_stats"
	cacheTTL   = 15 * time.Second
	fetchLimit = 5 * time.Second
)

// Service computes the global statistics.
type Service struct {
	Cache   *cache.Cache
	DevMode bool
	Servers []string // ACCEPTANCE_SERVERS
	// Local computes this server's own statistics (used in dev mode).
	Local func() *Local
}

// GlobalStats returns the stats of all servers: cached 15 s; unreachable servers get an "error" entry.
func (s *Service) GlobalStats(ctx context.Context) Global {
	c := s.Cache
	if c == nil {
		c = cache.Default
	}
	if v, ok := c.Get(cacheKey); ok && !s.DevMode {
		if g, ok := v.(Global); ok && len(g) > 0 {
			return g
		}
	}
	var g Global
	if s.DevMode {
		l := s.Local()
		b, _ := marshal(l)
		g = append(g, Entry{l.Host, b})
	} else {
		urls := make([]string, 0, len(s.Servers))
		byURL := map[string]string{}
		for _, srv := range s.Servers {
			u := srv + "/rest/local-stats"
			urls = append(urls, u)
			byURL[u] = srv
		}
		for _, r := range httpx.FetchParallel(ctx, urls, fetchLimit) {
			var probe struct {
				Host string `json:"host"`
			}
			if r.Err == nil && json.Unmarshal(r.Body, &probe) == nil && probe.Host != "" {
				g = append(g, Entry{probe.Host, json.RawMessage(bytes.TrimSpace(r.Body))})
				continue
			}
			srv := byURL[r.URL]
			host := srv
			if u, err := url.Parse(srv); err == nil && u.Hostname() != "" {
				host = u.Hostname()
			}
			b, _ := marshal(map[string]string{"host": host, "error": "unreachable"})
			g = append(g, Entry{host, b})
		}
	}
	c.Set(cacheKey, g, cacheTTL)
	return g
}
