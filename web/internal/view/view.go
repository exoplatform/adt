// Package view loads and renders the HTML templates and the JS/CSS fragments of the dashboard.
//
// Each package that renders markup owns a "templates" directory embedded in the binary and a Set built on it:
//
//	//go:embed templates
//	var templatesFS embed.FS
//
//	var tpl = view.New("pages", templatesFS, template.FuncMap{ ... })
//
// Files named *.tmpl are text/template files parsed together (they can call each other with {{ template }});
// every other file (*.css, *.html...) is a raw fragment returned as is by Raw, or inlined into a template
// with {{ raw "name.css" }}. The scripts are not fragments: they are static files (web/static/js). text/template is
// used on purpose, with the explicit {{ esc . }} function: html/template would escape quotes and JavaScript
// differently and change the bytes the pages have always sent.
//
// In development, ADT_WEB_SRC=<path of the web directory> makes every Set read its files from
// <path>/internal/<name>/templates on each render, so a template can be edited without rebuilding.
package view

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"text/template"
	"time"

	"github.com/exoplatform/adt/web/internal/phpx"
)

// Set is the templates and fragments of one package.
type Set struct {
	name  string
	embed fs.FS
	funcs template.FuncMap

	mu  sync.Mutex
	tpl *template.Template // parsed once from the embedded files (nil in development mode)
}

// New declares the Set of a package from its embedded "templates" directory. Parsing is lazy (first use), so
// that every file of the package can add its helper functions to funcs from its init() first; ParseAll, called
// by main, forces the parse of every Set at startup: a template that does not parse stops the program there
// instead of failing on a page. funcs adds to the functions every Set has: esc (phpx.Esc) and raw.
func New(name string, embedded fs.FS, funcs template.FuncMap) *Set {
	sub, err := fs.Sub(embedded, "templates")
	if err != nil {
		panic(fmt.Sprintf("view %s: %v", name, err))
	}
	s := &Set{name: name, embed: sub, funcs: funcs}
	registry = append(registry, s)
	return s
}

var registry []*Set

// ParseAll parses the templates of every Set and returns the first error.
func ParseAll() error {
	for _, s := range registry {
		if _, _, err := s.current(); err != nil {
			return fmt.Errorf("view %s: %w", s.name, err)
		}
	}
	return nil
}

// files is where the templates are read from: the embedded copy, or the disk in development mode.
func (s *Set) files() fs.FS {
	if src := os.Getenv("ADT_WEB_SRC"); src != "" {
		return os.DirFS(filepath.Join(src, "internal", s.name, "templates"))
	}
	return s.embed
}

func (s *Set) parse(fsys fs.FS) (*template.Template, error) {
	t := template.New(s.name).Option("missingkey=error").Funcs(template.FuncMap{
		"esc": phpx.Esc,
		"v":   AssetVersion,
		"raw": func(name string) (string, error) { return rawFrom(fsys, name) },
	}).Funcs(s.funcs)
	names, err := fs.Glob(fsys, "*.tmpl")
	if err != nil {
		return nil, err
	}
	for _, n := range names {
		b, err := fs.ReadFile(fsys, n)
		if err != nil {
			return nil, err
		}
		if _, err := t.New(n).Parse(string(b)); err != nil {
			return nil, err
		}
	}
	return t, nil
}

func rawFrom(fsys fs.FS, name string) (string, error) {
	b, err := fs.ReadFile(fsys, name)
	if err != nil {
		return "", fmt.Errorf("fragment %q: %w", name, err)
	}
	return string(b), nil
}

func (s *Set) current() (*template.Template, fs.FS, error) {
	fsys := s.files()
	s.mu.Lock()
	defer s.mu.Unlock()
	if fsys == s.embed { // embedded: parsed once
		if s.tpl == nil {
			t, err := s.parse(fsys)
			if err != nil {
				return nil, nil, err
			}
			s.tpl = t
		}
		return s.tpl, fsys, nil
	}
	t, err := s.parse(fsys) // development: re-read on each render
	return t, fsys, err
}

// Exec renders the template file name (for example "login.tmpl") with data.
func (s *Set) Exec(name string, data any) (string, error) {
	t, _, err := s.current()
	if err != nil {
		return "", err
	}
	var b bytes.Buffer
	if err := t.ExecuteTemplate(&b, name, data); err != nil {
		return "", fmt.Errorf("view %s: %s: %w", s.name, name, err)
	}
	return b.String(), nil
}

// Must is Exec for the page renderers, which write strings: a template error is a programming error.
func (s *Set) Must(name string, data any) string {
	out, err := s.Exec(name, data)
	if err != nil {
		panic(err)
	}
	return out
}

// Raw returns a fragment (a .js, .css or .html file of the templates directory) exactly as it is stored.
func (s *Set) Raw(name string) string {
	_, fsys, err := s.current()
	if err != nil {
		panic(err)
	}
	out, err := rawFrom(fsys, name)
	if err != nil {
		panic(err)
	}
	return out
}

var (
	assetDir string
	started  = time.Now()
)

// SetAssetDir tells where the static files are read from when they are not the embedded ones (development).
func SetAssetDir(dir string) { assetDir = dir }

// AssetVersion is the `?v=` cache buster of the stylesheet and scripts ({{ v }} in the templates): the process
// start time when the files are embedded (they only change with a new binary), the newest modification time of
// style.css and js/ when they are read from disk.
func AssetVersion() string {
	if assetDir == "" {
		return strconv.FormatInt(started.Unix(), 10)
	}
	var newest time.Time
	note := func(path string) {
		if st, err := os.Stat(path); err == nil && st.ModTime().After(newest) {
			newest = st.ModTime()
		}
	}
	note(filepath.Join(assetDir, "style.css"))
	if files, err := filepath.Glob(filepath.Join(assetDir, "js", "*.js")); err == nil {
		for _, f := range files {
			note(f)
		}
	}
	return strconv.FormatInt(newest.Unix(), 10)
}

// Trim removes the one newline a template file ends with, for fragments that are inlined in the middle of a line.
func Trim(s string) string { return strings.TrimSuffix(s, "\n") }
