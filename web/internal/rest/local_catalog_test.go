package rest

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"sync"
	"testing"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/config"
)

// ?remote= picks the catalog file of the add-ons host. Callers send the last segment of a catalog URL, so one plain file name is
// all that is accepted: whatever moves in the path or adds a query would let a host that may call this endpoint shape the
// request the server makes. The refused ones never reach the add-ons host.
func TestLocalCatalogRemoteIsOneFileName(t *testing.T) {
	var mu sync.Mutex
	var seen []string
	remote := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		seen = append(seen, r.URL.RequestURI())
		mu.Unlock()
		_, _ = w.Write([]byte("[]"))
	}))
	defer remote.Close()
	old := remoteBase
	remoteBase = remote.URL + "/"
	defer func() { remoteBase = old }()

	h := app.New(config.Config{DevMode: true}).Handler()
	get := func(rem string) int {
		r := httptest.NewRequest("GET", "/rest/local-catalog?plfversion=7.3.0&remote="+url.QueryEscape(rem), nil)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w.Code
	}

	for _, bad := range []string{"../../etc/x", "a/b", "/abs", "x?y=1", "x#f", "..", "a..b", "%2e%2e", "x y", "x\x00", "user@evil.example", ".hidden", "", "a\nb"} {
		if bad == "" {
			continue // an empty value is not a file name: handled by the same pattern below
		}
		if code := get(bad); code != http.StatusBadRequest {
			t.Errorf("remote=%q: %d, want 400", bad, code)
		}
	}
	mu.Lock()
	if len(seen) != 0 {
		t.Errorf("a refused value reached the add-ons host: %v", seen)
	}
	mu.Unlock()
	if code := get(""); code != http.StatusBadRequest {
		t.Errorf("empty remote: %d, want 400", code)
	}

	for _, good := range []string{"catalog", "catalog_stg.json", "plf-7.3-catalog"} {
		if code := get(good); code != http.StatusOK {
			t.Errorf("remote=%q: %d, want 200", good, code)
		}
	}
	mu.Lock()
	defer mu.Unlock()
	if len(seen) != 3 || seen[0] != "/catalog" || seen[1] != "/catalog_stg.json" || seen[2] != "/plf-7.3-catalog" {
		t.Errorf("requests made to the add-ons host: %v", seen)
	}
}
