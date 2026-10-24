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

// OriginFromRequest derives the Origin of a request: the host the visitor used (an alias such as the generic
// acceptance name included), as it is shown on the pages. Only its syntax is checked: it is the visitor's, so
// nothing that is published or cached for other people is built from it (see Store.Canonical).
func OriginFromRequest(r *http.Request) Origin {
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
	return Origin{Scheme: scheme, Host: host, Port: port}
}

// Canonical is the origin this server publishes and caches: the instance links (logs, statistics), the
// ACCEPTANCE_HOST that the other servers post the edit forms to, the name of the server in the statistics. It is
// the server's own ACCEPTANCE_HOST (the name of its virtual host), never the Host header of whoever asked: a visitor
// who sent another one would otherwise have it cached and merged into the lists of the other servers. The scheme and
// the port come from this server's entry of ACCEPTANCE_SERVERS. Without ACCEPTANCE_HOST (not configured), the visitor's
// host is used when it is one of the ACCEPTANCE_SERVERS, else the first of them. In development mode: the request.
func (s *Store) Canonical(o Origin) Origin {
	if s.cfg.DevMode {
		return o
	}
	defaultPort := func(scheme string) string { return map[string]string{"http": "80", "https": "443"}[scheme] }
	want := s.cfg.AcceptanceHost
	if want == "" {
		for _, server := range s.cfg.Servers {
			if u, err := url.Parse(server); err == nil && strings.EqualFold(u.Hostname(), o.Host) {
				return o
			}
		}
		if len(s.cfg.Servers) > 0 {
			want = hostOf(s.cfg.Servers[0])
		}
		if want == "" {
			return o
		}
	}
	for _, server := range s.cfg.Servers {
		if u, err := url.Parse(server); err == nil && strings.EqualFold(u.Hostname(), want) {
			c := Origin{Scheme: u.Scheme, Host: u.Hostname(), Port: u.Port()}
			if c.Port == "" {
				c.Port = defaultPort(c.Scheme)
			}
			return c
		}
	}
	return Origin{Scheme: o.Scheme, Host: want, Port: defaultPort(o.Scheme)}
}

func hostOf(server string) string {
	if u, err := url.Parse(server); err == nil {
		return u.Hostname()
	}
	return ""
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
