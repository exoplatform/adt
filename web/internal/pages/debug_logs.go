package pages

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/debugx"
	"github.com/exoplatform/adt/web/internal/logview"
)

// /debug-logs: tail of the Apache logs. Only files found in the log
// directory can be chosen; the request never supplies a path, and the file is opened through logview.
func init() {
	app.HandleFunc("GET /debug-logs", debugLogs)
}

// logTail returns the last lines of a file (at most the last 2 MiB), oldest first.
func logTail(f *os.File) []string {
	const maxBytes = 2097152
	st, err := f.Stat()
	if err != nil {
		return nil
	}
	start := max(0, st.Size()-maxBytes)
	buf, _ := io.ReadAll(io.NewSectionReader(f, start, maxBytes))
	lines := strings.Split(strings.TrimRight(string(buf), "\n"), "\n")
	if start > 0 {
		lines = lines[1:] // partial first line
	}
	return lines
}

func debugLogs(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	if dbgCheckCaches(c) {
		return
	}
	logDir := a.Cfg.DataDir + "/var/log/apache2"
	files := map[string]int64{}
	matches, _ := filepath.Glob(logDir + "/*.log")
	for _, f := range matches {
		if st, err := os.Stat(f); err == nil && st.Mode().IsRegular() {
			files[filepath.Base(f)] = st.Size()
		}
	}
	names := make([]string, 0, len(files))
	for n := range files {
		names = append(names, n)
	}
	sort.Strings(names)
	file := dbgQuery(r, "file")
	if _, ok := files[file]; !ok {
		file = ""
		if _, ok := files[c.Origin.Host+"-error.log"]; ok {
			file = c.Origin.Host + "-error.log"
		} else if len(names) > 0 {
			file = names[0]
		}
	}
	lines := 200
	if n := phpIntval(orDefault(dbgQuery(r, "lines"), "200")); n == 100 || n == 200 || n == 500 || n == 1000 || n == 2000 {
		lines = int(n)
	}
	q := strings.TrimSpace(dbgQuery(r, "q"))
	level := dbgQuery(r, "level")
	status := dbgQuery(r, "status")
	_, refresh := r.URL.Query()["refresh"]

	var out []string
	if file != "" {
		var levelRe, statusRe *regexp.Regexp
		if level != "" {
			levelRe = regexp.MustCompile(`\[[a-z_0-9]+:` + regexp.QuoteMeta(level) + `\]`)
		}
		if status != "" {
			if status[0] < 0x80 {
				statusRe = regexp.MustCompile(`" ` + regexp.QuoteMeta(status[:1]) + `\d\d `)
			} else {
				statusRe = regexp.MustCompile(`$^`) // a byte that is not text: nothing matches
			}
		}
		if f, err := logview.OpenIn([]string{logDir}, logDir+"/"+file); err == nil {
			ql := asciiLower(q)
			for _, line := range logTail(f) {
				if q != "" && !strings.Contains(asciiLower(line), ql) {
					continue
				}
				if levelRe != nil && !levelRe.MatchString(line) {
					continue
				}
				if statusRe != nil && !statusRe.MatchString(line) {
					continue
				}
				out = append(out, line)
			}
			_ = f.Close()
			if len(out) > lines {
				out = out[len(out)-lines:]
			}
		}
	}
	isError := strings.HasSuffix(file, "-error.log")

	debugx.PageBegin(c, "logs", "Debug Apache logs", "Tail of the frontend and instance Apache logs", false)
	type fileOpt struct {
		Value, Size string
		Selected    bool
	}
	fileOpts := make([]fileOpt, len(names))
	for i, n := range names {
		fileOpts[i] = fileOpt{n, debugx.Bytes(float64(files[n])), n == file}
	}
	lineOpts := make([]debugOption, 0, 5)
	for _, n := range []int{100, 200, 500, 1000, 2000} {
		lineOpts = append(lineOpts, debugOption{strconv.Itoa(n), n == lines})
	}
	c.WriteString(tpl.Must("debug_logs.tmpl", map[string]any{
		"Files":    fileOpts,
		"Lines":    lineOpts,
		"IsError":  isError,
		"Levels":   debugOptions([]string{"error", "warn", "notice", "info", "debug"}, level),
		"Statuses": debugOptions([]string{"2xx", "3xx", "4xx", "5xx"}, status),
		"Q":        q,
		"Refresh":  refresh,
		"NoFile":   file == "",
		"LogDir":   logDir,
		"Count":    len(out),
		"File":     file,
		"Text":     strings.Join(out, "\n"),
	}))
	debugx.PageEnd(c)
}

func orDefault(s, def string) string {
	if s == "" {
		return def
	}
	return s
}
