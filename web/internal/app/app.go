// Package app wires the process: configuration, shared services and the route table.
//
// Pages register themselves from init() with Handle, so porting a page means adding one file; no shared
// file needs editing and parallel work does not conflict.
package app

import (
	"io/fs"
	"net/http"
	"sort"
	"strings"

	"github.com/exoplatform/adt/web/internal/auth"
	"github.com/exoplatform/adt/web/internal/config"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/static"
)

// App is what every handler gets: the configuration and the shared services.
type App struct {
	Cfg       config.Config
	Instances *instances.Store
}

type route struct {
	pattern string
	build   func(*App) http.Handler
}

var routes []route

// Handle registers a handler for a ServeMux pattern ("GET /qa", "/rest/local-instances"...).
// build is called once at startup with the App, so handlers can close over its services.
// Call it from init() in the page's file.
func Handle(pattern string, build func(*App) http.Handler) {
	routes = append(routes, route{pattern, build})
}

// HandleFunc is Handle for a plain handler func taking the App.
func HandleFunc(pattern string, f func(*App, http.ResponseWriter, *http.Request)) {
	Handle(pattern, func(a *App) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { f(a, w, r) })
	})
}

// New builds the App.
func New(cfg config.Config) *App { return &App{Cfg: cfg, Instances: instances.NewStore(cfg)} }

// Handler returns the HTTP handler: identity middleware, registered pages, then static files.
func (a *App) Handler() http.Handler {
	mux := http.NewServeMux()
	sort.SliceStable(routes, func(i, j int) bool { return routes[i].pattern < routes[j].pattern })
	for _, rt := range routes {
		mux.Handle(rt.pattern, rt.build(a))
	}
	var files fs.FS = static.FS
	if a.Cfg.StaticDir != "" {
		files = osFS(a.Cfg.StaticDir)
	}
	fileServer := http.FileServerFS(files)
	// Registered for every method ("/" and not "GET /"): the mux rejects, at startup, a method-less page
	// pattern such as "/server-stats" next to a "GET /" fallback as conflicting. This way a page may register
	// with or without a method.
	// Liveness for monitoring, reached on the socket directly (Apache protects every public path):
	//   curl --unix-socket /run/adt-web/adt-web.sock http://localhost/healthz
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.Handle("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Unknown paths get the static 404 page; directories are never listed.
		p := strings.TrimPrefix(r.URL.Path, "/")
		isFile := false
		if f, err := files.Open(p); err == nil {
			if st, err := f.Stat(); err == nil && !st.IsDir() {
				isFile = true
			}
			_ = f.Close()
		}
		if (r.Method != http.MethodGet && r.Method != http.MethodHead) || !isFile || p == "" {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			b, _ := fs.ReadFile(files, "errors/404.html")
			a.StaticPageCSP(w, b)
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write(b)
			return
		}
		w.Header().Del("Pragma")
		w.Header().Set("Cache-Control", staticCacheControl(p))
		if ct := staticContentType(p); ct != "" {
			w.Header().Set("Content-Type", ct)
		}
		fileServer.ServeHTTP(w, r)
	}))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := auth.FromHeaders(r)
		if a.Cfg.DevMode && id.User == "" {
			id = auth.Identity{User: a.Cfg.DevUser, Name: a.Cfg.DevName, Mail: a.Cfg.DevMail}
		}
		// Dynamic pages are never cached; the static file
		// handler above replaces this with the lifetimes of staticCacheControl.
		h := w.Header()
		h.Set("Cache-Control", dynamicCacheControl)
		h.Set("Pragma", "no-cache")
		mux.ServeHTTP(&cspWriter{ResponseWriter: w, a: a}, auth.With(r, id))
	})
}
