package rest

import (
	"bytes"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"math"
	"net/http"
	"os"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/exoplatform/adt/web/internal/app"
)

// /rest/local-catalog: add-ons catalog of this server. The former .php name is still served for the instances that
// were deployed with it.
//
// The catalog files (<major>/{local,staging}_catalog.json) are static data served by this
// endpoint: they are embedded from ./catalog, and ADT_CATALOG_DIR,
// when set, serves them from disk instead (same layout).
//
//go:embed catalog
var catalogFS embed.FS

func init() {
	app.HandleFunc("GET /rest/local-catalog.php", localCatalog)
	app.HandleFunc("GET /rest/local-catalog", localCatalog)
}

// Strict version pattern: unescaped dots would match any character, which would let `"` or `\` reach
// the JSON text.
var (
	plfVersionRe = regexp.MustCompile(`^[0-9]\.[0-9]\.[0-9](-(exo|meed))?(-([0-9]{8,10}|(M|RC|CP)[0-9]{2}))?$`)
	plfSuffixRe  = regexp.MustCompile(`^[0-9]\.[0-9]\.[0-9](-(exo|meed))?`)
)

const (
	remoteTimeout = 30 * time.Second
	maxRemote     = 32 << 20
)

// Remote catalogs (variables so that tests can point them at a local server).
var (
	remoteBase    = "http://addons.exoplatform.org/"
	remoteDefault = "https://www.exoplatform.com/addons/catalog"
)

func plain(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "text/html; charset=UTF-8")
	w.WriteHeader(code)
	_, _ = io.WriteString(w, msg)
}

// lastParam is the value of query parameter name: with repeated parameters the last one wins.
func lastParam(r *http.Request, name string) (string, bool) {
	v, ok := r.URL.Query()[name]
	if !ok || len(v) == 0 {
		return "", false
	}
	return v[len(v)-1], true
}

func readCatalogFile(major, target string) ([]byte, bool) {
	name := major + "/" + target + "_catalog.json"
	if dir := os.Getenv("ADT_CATALOG_DIR"); dir != "" {
		b, err := fs.ReadFile(os.DirFS(dir), name)
		return b, err == nil
	}
	b, err := fs.ReadFile(catalogFS, "catalog/"+name)
	return b, err == nil
}

func localCatalog(a *app.App, w http.ResponseWriter, r *http.Request) {
	version, ok := lastParam(r, "plfversion")
	if !ok {
		plain(w, http.StatusNotFound, "Error! Missing PLF version parameter!")
		return
	}
	staging := false
	if s, ok := lastParam(r, "staging"); ok && s == "true" {
		staging = true
	}
	target := "local"
	if staging {
		target = "staging"
	}
	if !plfVersionRe.MatchString(version) {
		plain(w, http.StatusNotFound, "Error! Invalid PLF version parameter value!")
		return
	}
	major := version[:3]
	raw, found := readCatalogFile(major, target)
	if !found {
		plain(w, http.StatusNotFound, "Error! Could not find "+target+" catalog file for "+major+" version!")
		return
	}
	suffix := plfSuffixRe.ReplaceAllString(version, "")
	text := string(raw)
	text = strings.ReplaceAll(text, "@exo_plf_version_suffix", suffix)
	text = strings.ReplaceAll(text, "@exo_plf_version", version)
	text = strings.ReplaceAll(text, "@exo_plf_minor_version", version[4:5])

	remoteURL := remoteDefault
	if rem, ok := lastParam(r, "remote"); ok {
		// only the path of the add-ons host can be chosen; reject anything that is not a plain URL path/query
		for _, c := range []byte(rem) {
			if c <= ' ' || c == 0x7f {
				plain(w, http.StatusBadRequest, "Error! Invalid remote parameter value!")
				return
			}
		}
		remoteURL = remoteBase + rem
	}
	local, err1 := decodeList(text)
	remote, err2 := fetchRemoteCatalog(r, remoteURL)
	if err1 != nil || err2 != nil {
		// a catalog that cannot be decoded is a server error
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	merged := append(append([]any{}, local...), remote...)
	if staging {
		var uniq []any
		for _, o := range merged {
			if !hasDuplicate(uniq, o) {
				uniq = append(uniq, o)
			}
		}
		merged = uniq
	}
	var b bytes.Buffer
	phpPretty(&b, merged, 0)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_, _ = w.Write(b.Bytes())
}

func fetchRemoteCatalog(r *http.Request, u string) ([]any, error) {
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, u, nil)
	if err != nil {
		return nil, err
	}
	resp, err := (&http.Client{Timeout: remoteTimeout}).Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxRemote+1))
	if err != nil || len(body) > maxRemote {
		return nil, errors.New("remote catalog unreadable")
	}
	return decodeList(string(body))
}

// ---- minimal ordered JSON (the key order is kept; encoding/json maps do not) ----

type jobj struct {
	keys []string
	vals map[string]any
}

func decodeList(s string) ([]any, error) {
	dec := json.NewDecoder(strings.NewReader(s))
	dec.UseNumber()
	v, err := decodeValue(dec, 0)
	if err != nil {
		return nil, err
	}
	if dec.More() {
		return nil, errors.New("trailing data")
	}
	l, ok := v.([]any)
	if !ok {
		return nil, errors.New("not a list")
	}
	return l, nil
}

// maxJSONDepth bounds the nesting of the decoded document: the recursion below would otherwise overflow the stack
// (a fatal error no recover catches) on a body made of nothing but "[".
const maxJSONDepth = 100

func decodeValue(dec *json.Decoder, depth int) (any, error) {
	if depth > maxJSONDepth {
		return nil, errors.New("JSON nested too deeply")
	}
	t, err := dec.Token()
	if err != nil {
		return nil, err
	}
	switch d := t.(type) {
	case json.Delim:
		if d == '[' {
			out := []any{}
			for dec.More() {
				v, err := decodeValue(dec, depth+1)
				if err != nil {
					return nil, err
				}
				out = append(out, v)
			}
			_, err := dec.Token()
			return out, err
		}
		o := &jobj{vals: map[string]any{}}
		for dec.More() {
			kt, err := dec.Token()
			if err != nil {
				return nil, err
			}
			k := kt.(string)
			v, err := decodeValue(dec, depth+1)
			if err != nil {
				return nil, err
			}
			if _, dup := o.vals[k]; !dup {
				o.keys = append(o.keys, k)
			}
			o.vals[k] = v
		}
		_, err = dec.Token()
		return o, err
	default:
		return t, nil
	}
}

func fieldOf(v any, key string) any {
	if o, ok := v.(*jobj); ok {
		return o.vals[key]
	}
	return nil
}

func hasDuplicate(arr []any, obj any) bool {
	for _, v := range arr {
		if looseEq(fieldOf(v, "id"), fieldOf(obj, "id")) && looseEq(fieldOf(v, "version"), fieldOf(obj, "version")) {
			return true
		}
	}
	return false
}

// looseEq compares decoded JSON scalars loosely: numeric strings compare as numbers.
func looseEq(a, b any) bool {
	as, aok := a.(string)
	bs, bok := b.(string)
	if aok && bok {
		fa, ea := strconv.ParseFloat(strings.TrimSpace(as), 64)
		fb, eb := strconv.ParseFloat(strings.TrimSpace(bs), 64)
		if ea == nil && eb == nil {
			return fa == fb
		}
		return as == bs
	}
	return reflect.DeepEqual(a, b)
}

func phpPretty(b *bytes.Buffer, v any, depth int) {
	ind := func(n int) { b.WriteString(strings.Repeat("    ", n)) }
	switch x := v.(type) {
	case nil:
		b.WriteString("null")
	case bool:
		b.WriteString(strconv.FormatBool(x))
	case json.Number:
		b.WriteString(phpNumber(x))
	case string:
		phpString(b, x)
	case []any:
		if len(x) == 0 {
			b.WriteString("[]")
			return
		}
		b.WriteString("[\n")
		for i, e := range x {
			ind(depth + 1)
			phpPretty(b, e, depth+1)
			if i < len(x)-1 {
				b.WriteByte(',')
			}
			b.WriteByte('\n')
		}
		ind(depth)
		b.WriteByte(']')
	case *jobj:
		if len(x.keys) == 0 {
			b.WriteString("[]") // an empty object encodes as []
			return
		}
		b.WriteString("{\n")
		for i, k := range x.keys {
			ind(depth + 1)
			phpString(b, k)
			b.WriteString(": ")
			phpPretty(b, x.vals[k], depth+1)
			if i < len(x.keys)-1 {
				b.WriteByte(',')
			}
			b.WriteByte('\n')
		}
		ind(depth)
		b.WriteByte('}')
	}
}

func phpNumber(n json.Number) string {
	s := n.String()
	if i, err := strconv.ParseInt(s, 10, 64); err == nil {
		return strconv.FormatInt(i, 10)
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil || math.IsInf(f, 0) {
		return "0"
	}
	if af := math.Abs(f); af != 0 && (af < 1e-4 || af >= 1e15) {
		e := strconv.FormatFloat(f, 'e', -1, 64) // 1e+25 -> 1.0e+25
		mant, exp, _ := strings.Cut(e, "e")
		if !strings.Contains(mant, ".") {
			mant += ".0"
		}
		if len(exp) > 2 && (exp[1] == '0') {
			exp = exp[:1] + strings.TrimLeft(exp[1:], "0")
		}
		return mant + "e" + exp
	}
	return strconv.FormatFloat(f, 'f', -1, 64)
}

// phpString writes the JSON string form with "\/" post-processed to "/":
// non-ASCII is \uXXXX escaped, slashes are plain.
func phpString(b *bytes.Buffer, s string) {
	b.WriteByte('"')
	for _, r := range s {
		switch {
		case r == '"':
			b.WriteString(`\"`)
		case r == '\\':
			b.WriteString(`\\`)
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
		case r < 0x20:
			fmt.Fprintf(b, `\u%04x`, r)
		case r < 0x80:
			b.WriteRune(r)
		case r >= 0x10000:
			r1, r2 := utf16.EncodeRune(r)
			fmt.Fprintf(b, `\u%04x\u%04x`, r1, r2)
		default:
			fmt.Fprintf(b, `\u%04x`, r)
		}
	}
	b.WriteByte('"')
}
