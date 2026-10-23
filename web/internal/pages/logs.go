package pages

import (
	"io"
	"net/http"
	"net/url"
	"path/filepath"
	"strconv"
	"strings"
	"unicode/utf16"
	"unicode/utf8"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/logview"
)

// /logs, /logsTail, /logsDownload: the log viewer, its live tail endpoint and the download.
// The file is chosen with type=instance|apache and
// file=<absolute path>; every one of the three goes through logview.Policy, which only allows the log files
// below the log directories (see package logview).
func init() {
	funcs["logsQuery"] = url.QueryEscape
	app.HandleFunc("GET /logs", logsPage)
	app.HandleFunc("GET /logsTail", logsTail)
	app.HandleFunc("GET /logsDownload", logsDownload)
}

// phpJSONString is the JSON encoding of a string: slashes and non ASCII characters escaped, and also
// < > & (JSON_HEX_TAG|JSON_HEX_AMP) because the value is written inside a <script>.
func phpJSONString(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for i := 0; i < len(s); {
		r, n := utf8.DecodeRuneInString(s[i:])
		i += n
		switch {
		case r == utf8.RuneError && n == 1:
			b.WriteString(`\ufffd`)
		case r == '"':
			b.WriteString(`\"`)
		case r == '\\':
			b.WriteString(`\\`)
		case r == '/':
			b.WriteString(`\/`)
		case r == '\b':
			b.WriteString(`\b`)
		case r == '\f':
			b.WriteString(`\f`)
		case r == '\n':
			b.WriteString(`\n`)
		case r == '\r':
			b.WriteString(`\r`)
		case r == '\t':
			b.WriteString(`\t`)
		case r < 0x20 || r == '<' || r == '>' || r == '&' || r == '\'' || r == 0x7f:
			b.WriteString(`\u` + strconv.FormatInt(int64(0x10000+r), 16)[1:])
		case r < 0x80:
			b.WriteRune(r)
		case r >= 0x10000:
			r1, r2 := utf16.EncodeRune(r)
			b.WriteString(`\u` + strconv.FormatInt(int64(r1), 16) + `\u` + strconv.FormatInt(int64(r2), 16))
		default:
			b.WriteString(`\u` + strconv.FormatInt(int64(0x10000+r), 16)[1:])
		}
	}
	b.WriteByte('"')
	return b.String()
}

func logsPage(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	filePath := dbgQuery(r, "file")
	logType := dbgQuery(r, "type")
	if dbgCheckCaches(c) {
		return
	}
	c.Begin("log visualization", false)
	data := struct {
		File, Type, Base, HumanSize, Content string
		Size                                 int64
		Denied, TooLarge                     bool
	}{File: filePath, Type: logType}
	f, err := logview.NewPolicy(a.Cfg.DataDir).Open(logType, filePath)
	if err != nil {
		data.Denied = true
	} else {
		defer f.Close()
		st, _ := f.Stat()
		data.Size = st.Size()
		data.Base = filepath.Base(filePath)
		data.HumanSize = logview.HumanFilesize(data.Size, 0)
		if data.TooLarge = logview.TooLargeToBeViewed(data.Size); !data.TooLarge {
			content, _ := io.ReadAll(io.NewSectionReader(f, 0, logview.ViewLimit))
			data.Content = logview.Render(string(content))
		}
	}
	c.WriteString(tpl.Must("logs.tmpl", data))
	c.End()
}

// logsTail serves the part of the file written after offset, as JSON.
func logsTail(a *app.App, w http.ResponseWriter, r *http.Request) {
	h := w.Header()
	h.Set("Content-Type", "application/json")
	h.Set("Cache-Control", "no-store")
	h.Set("X-Content-Type-Options", "nosniff")
	offset := max(0, phpIntval(dbgQuery(r, "offset")))
	f, err := logview.NewPolicy(a.Cfg.DataDir).Open(dbgQuery(r, "type"), dbgQuery(r, "file"))
	if err != nil {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"error":"Not authorized to read this file."}`))
		return
	}
	defer f.Close()
	t, err := logview.ReadTail(f, offset)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"Cannot read this file."}`))
		return
	}
	_, _ = w.Write([]byte(`{"size":` + strconv.FormatInt(t.Size, 10) +
		`,"truncated":` + strconv.FormatBool(t.Truncated) +
		`,"skipped":` + strconv.FormatInt(t.Skipped, 10) +
		`,"data":` + phpJSONString(logview.Render(string(t.Data))) + `}`))
}

// downloadName is the file name for Content-Disposition: the base name with everything that could break
// out of the quoted string (quotes, backslashes, control characters, path separators) replaced.
func downloadName(p string) string {
	return strings.Map(func(r rune) rune {
		if r < 0x20 || r == 0x7f || r == '"' || r == '\\' || r == '/' || r == ';' || r == '%' {
			return '_'
		}
		return r
	}, strings.ToValidUTF8(filepath.Base(p), "_"))
}

// logsDownload sends the whole file as an attachment.
func logsDownload(a *app.App, w http.ResponseWriter, r *http.Request) {
	h := w.Header()
	h.Set("X-Content-Type-Options", "nosniff")
	f, err := logview.NewPolicy(a.Cfg.DataDir).Open(dbgQuery(r, "type"), dbgQuery(r, "file"))
	if err != nil {
		h.Set("Content-Type", "text/html; charset=UTF-8")
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`<div class="alert alert-danger">Not authorized to download this file.</div>`))
		return
	}
	defer f.Close()
	st, _ := f.Stat()
	h.Set("Content-Description", "File Transfer")
	h.Set("Content-Type", "application/octet-stream")
	h.Set("Content-Disposition", `attachment; filename="`+downloadName(dbgQuery(r, "file"))+`"`)
	h.Set("Expires", "0")
	h.Set("Cache-Control", "must-revalidate")
	h.Set("Pragma", "public")
	h.Set("Content-Length", strconv.FormatInt(st.Size(), 10))
	// exactly the announced size, even when the log grows meanwhile
	_, _ = io.Copy(w, io.NewSectionReader(f, 0, st.Size()))
}
