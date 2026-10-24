package stats

import (
	"net/http"
	"sync"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
)

var (
	svcOnce sync.Once
	svc     *Service
)

// LocalFor computes this server's statistics for the request (host = SERVER_NAME, instances = the
// local acceptance instances).
func LocalFor(a *app.App, r *http.Request) *Local {
	o := a.Instances.Canonical(instances.OriginFromRequest(r)) // the name of this server, not the visitor's Host
	var all []instances.Instance
	if b := a.Instances.Local(o); b != nil {
		for _, k := range b.Keys() {
			all = append(all, b.Get(k)...)
		}
	}
	return ComputeLocal(o.Host, a.Cfg.DataDir, all)
}

// For returns the process-wide Service of the app (stats of every acceptance server, cached 15 s).
// The request is only used in dev mode, to name and describe the local server.
func For(a *app.App, r *http.Request) Global {
	svcOnce.Do(func() {
		svc = &Service{DevMode: a.Cfg.DevMode, Servers: a.Cfg.Servers}
	})
	local := func() *Local { return LocalFor(a, r) }
	// Local is per request (host comes from the request); the rest of the service is shared.
	s := *svc
	s.Local = local
	return s.GlobalStats(r.Context())
}
