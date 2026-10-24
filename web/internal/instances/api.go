package instances

// This file is the API of the data layer (this package) for its consumers (ui, pages, rest).

import (
	"context"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/config"
	"github.com/exoplatform/adt/web/internal/httpx"
)

// Origin is what is needed to build absolute URLs: the scheme, SERVER_NAME and SERVER_PORT of
// the dashboard being served. Behind Apache, the scheme comes from X-Forwarded-Proto and the port is the
// default one of the scheme unless the Host header carries one (Apache preserves the host).
type Origin struct{ Scheme, Host, Port string }

var (
	hostNameRe = regexp.MustCompile(`^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$`)
	portRe     = regexp.MustCompile(`^[0-9]{1,5}$`)
)

// OriginFromRequest derives the Origin of a request. The Host header is the visitor's: it ends up in links of the
// pages and in the lists other servers merge, and those are cached, so a Host that is not one of the
// ACCEPTANCE_SERVERS (outside the development mode) is not used: the origin of the first of them is.
func OriginFromRequest(r *http.Request, cfg config.Config) Origin {
	scheme := "http"
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	host, port, err := net.SplitHostPort(r.Host)
	if err != nil {
		host, port = r.Host, map[string]string{"http": "80", "https": "443"}[scheme]
	}
	if !hostNameRe.MatchString(host) || !portRe.MatchString(port) {
		host, port = "localhost", map[string]string{"http": "80", "https": "443"}[scheme]
	}
	own := Origin{Scheme: scheme, Host: host, Port: port}
	if cfg.DevMode || len(cfg.Servers) == 0 {
		return own
	}
	for _, s := range cfg.Servers {
		if u, err := url.Parse(s); err == nil && strings.EqualFold(u.Hostname(), host) {
			return own
		}
	}
	u, err := url.Parse(cfg.Servers[0])
	if err != nil || u.Hostname() == "" {
		return own
	}
	o := Origin{Scheme: u.Scheme, Host: u.Hostname(), Port: u.Port()}
	if o.Port == "" {
		o.Port = map[string]string{"http": "80", "https": "443"}[u.Scheme]
	}
	return o
}

// Store gives access to the instances of this server (Local) and of all the acceptance servers (Global),
// with caches (2 min fresh, stale copy served while refreshing).
//
// The *Branches returned are shared with the cache: read them, never modify them.
type Store struct {
	cfg config.Config
	// Cache holds the cached instance lists (and is what ClearCaches empties). It defaults to cache.Default,
	// the process-wide cache, so other services (features, stats, ...) can share it.
	Cache *cache.Cache

	localMu, globalMu sync.Mutex
	// fetch downloads the ACCEPTANCE_SERVERS answers (httpx.FetchParallel; replaced in tests).
	fetch func(ctx context.Context, urls []string, timeout time.Duration) []httpx.Result
}

// NewStore builds the store.
func NewStore(cfg config.Config) *Store { return &Store{cfg: cfg, Cache: cache.Default} }
