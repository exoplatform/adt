package pages

import (
	"context"
	"fmt"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/debugx"
	"github.com/exoplatform/adt/web/internal/sessions"
)

// /debug-health: host, disk, Docker and deployment state.
func init() {
	app.HandleFunc("GET /debug-health", debugHealth)
}

// healthRun runs a command (argv, no shell) with a 5 second limit and returns its output lines, or nil when
// it is unavailable or prints nothing.
func healthRun(name string, args ...string) []string {
	lines, _ := healthRunOK(name, args...)
	if len(lines) == 0 {
		return nil
	}
	return lines
}

// healthRunOK is healthRun that also says whether the command could be run: ok is false when it is missing,
// times out or fails without output, and true when it ran, even if it printed nothing (docker on a host
// without any container).
func healthRunOK(name string, args ...string) (lines []string, ok bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, name, args...).Output()
	if err != nil && len(out) == 0 {
		return nil, false
	}
	s := strings.TrimSpace(string(out))
	if s == "" {
		return nil, true
	}
	return strings.Split(s, "\n"), true
}

// healthRowData is one label/value row of the health tables: Value is printed as is, escaped when Esc, in a
// <code> when Code; Suffix and Meter follow it.
type healthRowData struct {
	Label, Value, Suffix string
	Esc, Code            bool
	Meter                *healthBar
}

// healthBar is a usage meter.
type healthBar struct{ Pct, Class string }

func healthMeter(used, total float64) *healthBar {
	pct := 0.0
	if total > 0 {
		pct = math.Round(100 * used / total)
	}
	class := "bg-success"
	if pct >= 90 {
		class = "bg-danger"
	} else if pct >= 75 {
		class = "bg-warning"
	}
	return &healthBar{strconv.Itoa(int(pct)), class}
}

func debugHealth(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	if dbgCheckCaches(c) {
		return
	}
	data := a.Cfg.DataDir
	if data == "" {
		data = "/"
	}

	// host
	uptime := int64(-1)
	if b, err := os.ReadFile("/proc/uptime"); err == nil {
		if f := strings.Fields(string(b)); len(f) > 0 {
			if x, err := strconv.ParseFloat(f[0], 64); err == nil {
				uptime = int64(x)
			}
		}
	}
	load := ""
	if b, err := os.ReadFile("/proc/loadavg"); err == nil {
		if f := strings.Fields(string(b)); len(f) >= 3 {
			var parts []string
			for _, s := range f[:3] {
				x, _ := strconv.ParseFloat(s, 64)
				parts = append(parts, fmt.Sprintf("%.2f", x))
			}
			load = strings.Join(parts, " / ")
		}
	}
	mem := map[string]float64{}
	if b, err := os.ReadFile("/proc/meminfo"); err == nil {
		for _, l := range strings.Split(string(b), "\n") {
			f := strings.Fields(l)
			if len(f) == 3 && f[2] == "kB" && strings.HasSuffix(f[0], ":") {
				if x, err := strconv.ParseFloat(f[1], 64); err == nil {
					mem[strings.TrimSuffix(f[0], ":")] = x * 1024
				}
			}
		}
	}

	// filesystems
	type fsInfo struct {
		path        string
		total, used float64
	}
	var fsList []fsInfo
	seenPath := map[string]bool{}
	for _, p := range []string{data, data + "/var/log", "/tmp"} {
		if p == "" || seenPath[p] {
			continue
		}
		seenPath[p] = true
		if st, err := os.Stat(p); err != nil || !st.IsDir() {
			continue
		}
		var s syscall.Statfs_t
		if syscall.Statfs(p, &s) != nil {
			continue
		}
		total := float64(s.Blocks) * float64(s.Bsize)
		free := float64(s.Bavail) * float64(s.Bsize)
		if total > 0 {
			fsList = append(fsList, fsInfo{p, total, total - free})
		}
	}

	// directory sizes, only on demand (du can be slow)
	_, wantSizes := r.URL.Query()["sizes"]
	type dirSize struct {
		dir  string
		size int64
	}
	var sizes []dirSize
	if wantSizes {
		for _, d := range []string{"var/log/apache2", "var/sessions", "var/audit", "conf", "sources", "downloads", "datasets"} {
			size := int64(-1)
			if st, err := os.Stat(data + "/" + d); err == nil && st.IsDir() {
				if out := healthRun("du", "-sk", data+"/"+d); out != nil {
					if f := strings.Fields(out[0]); len(f) > 0 {
						if n, err := strconv.ParseInt(f[0], 10, 64); err == nil && n > 0 {
							size = n * 1024
						}
					}
				}
			}
			sizes = append(sizes, dirSize{d, size})
		}
	}

	// docker (the format string reaches docker with a literal \t, which its template turns into a tab)
	docker, dockerOK := healthRunOK("docker", "ps", "-a", "--format", `{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.State}}`)

	// deployments
	descriptors, _ := filepath.Glob(data + "/conf/adt/*")
	var lastDeploy int64
	for _, f := range descriptors {
		if st, err := os.Stat(f); err == nil && st.ModTime().Unix() > lastDeploy {
			lastDeploy = st.ModTime().Unix()
		}
	}
	sess, _ := filepath.Glob(sessions.For(a.Cfg.DataDir).Dir() + "/*.json")

	// cache backend
	_, cs := cache.Default.Inspect()
	cacheBackend := fmt.Sprintf("In-process cache (%d entries, %d hits / %d misses)", cs.Entries, cs.Hits, cs.Misses)

	host, _ := os.Hostname()
	debugx.PageBegin(c, "health", "Debug Health", "Host, disk, Docker and deployment state", false)

	uptimeRow := healthRowData{Label: "Uptime", Value: "n/a"}
	if uptime >= 0 {
		uptimeRow.Value = sessions.DurationLabel(uptime)
	}
	loadRow := healthRowData{Label: "Load average", Value: "n/a"}
	if load != "" {
		loadRow.Value, loadRow.Esc = load, true
	}
	var memRows []healthRowData
	if mem["MemTotal"] > 0 {
		avail, ok := mem["MemAvailable"]
		if !ok {
			avail = mem["MemFree"]
		}
		used := mem["MemTotal"] - avail
		memRows = append(memRows, healthRowData{Label: "Memory", Value: debugx.Bytes(used) + " / " + debugx.Bytes(mem["MemTotal"]), Meter: healthMeter(used, mem["MemTotal"])})
	}
	if mem["SwapTotal"] > 0 {
		su := mem["SwapTotal"] - mem["SwapFree"]
		memRows = append(memRows, healthRowData{Label: "Swap", Value: debugx.Bytes(su) + " / " + debugx.Bytes(mem["SwapTotal"]), Meter: healthMeter(su, mem["SwapTotal"])})
	}
	software := []healthRowData{
		{Label: "Web server", Value: "adt-web (Go net/http behind Apache)"},
		{Label: "Go", Value: runtime.Version(), Esc: true},
		{Label: "Cache backend", Value: cacheBackend, Esc: true},
		{Label: "ADT_DATA", Value: data, Code: true},
		{Label: "Time (UTC)", Value: time.Now().UTC().Format("2006-01-02 15:04:05")},
	}

	type diskRow struct {
		Path, Used, Total string
		Meter             *healthBar
	}
	var disks []diskRow
	for _, f := range fsList {
		disks = append(disks, diskRow{f.path, debugx.Bytes(f.used), debugx.Bytes(f.total), healthMeter(f.used, f.total)})
	}
	type sizeRow struct{ Dir, Size string }
	var sizeRows []sizeRow
	for _, s := range sizes {
		v := "n/a"
		if s.size >= 0 {
			v = debugx.Bytes(float64(s.size))
		}
		sizeRows = append(sizeRows, sizeRow{s.dir, v})
	}

	lastRow := healthRowData{Label: "Last deployment", Value: "n/a"}
	if lastDeploy != 0 {
		lastRow.Value, lastRow.Esc = time.Unix(lastDeploy, 0).UTC().Format("2006-01-02 15:04"), true
		lastRow.Suffix = " UTC (" + sessions.DurationLabel(time.Now().Unix()-lastDeploy) + " ago)"
	}
	deployments := []healthRowData{
		{Label: "Instance descriptors", Value: strconv.Itoa(len(descriptors))},
		lastRow,
		{Label: "Tracked login sessions", Value: strconv.Itoa(len(sess))},
	}

	type container struct{ Name, Image, Status, Badge string }
	var containers []container
	for _, line := range docker {
		f := strings.Split(line, "\t")
		for len(f) < 4 {
			f = append(f, "")
		}
		badge := "bg-secondary"
		switch f[3] {
		case "running":
			badge = "bg-success"
		case "exited":
			badge = "bg-danger"
		}
		containers = append(containers, container{f[0], f[1], f[2], badge})
	}

	c.WriteString(tpl.Must("debug_health.tmpl", map[string]any{
		"Hostname":    healthRowData{Label: "Hostname", Value: host, Esc: true},
		"Uptime":      uptimeRow,
		"Load":        loadRow,
		"Mem":         memRows,
		"Software":    software,
		"Disks":       disks,
		"WantSizes":   wantSizes,
		"Sizes":       sizeRows,
		"Deployments": deployments,
		"DockerOK":    dockerOK,
		"Containers":  containers,
	}))
	debugx.PageEnd(c)
}
