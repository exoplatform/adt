package instances

// The global (all acceptance servers) part of the data layer: merging the instances of every server, sorting
// them, and the category getters.

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/httpx"
)

const (
	fetchTimeout   = 5 * time.Second
	freshTTL       = 120 * time.Second
	staleTTL       = 1800 * time.Second
	retryTTL       = 15 * time.Second
	refreshLockTTL = 30 * time.Second
)

// strcasecmp compares bytes after ASCII lower-casing.
func strcasecmp(a, b string) int {
	lower := func(c byte) byte {
		if c >= 'A' && c <= 'Z' {
			return c + 32
		}
		return c
	}
	n := len(a)
	if len(b) < n {
		n = len(b)
	}
	for i := 0; i < n; i++ {
		if x, y := lower(a[i]), lower(b[i]); x != y {
			if x < y {
				return -1
			}
			return 1
		}
	}
	switch {
	case len(a) < len(b):
		return -1
	case len(a) > len(b):
		return 1
	}
	return 0
}

// CmpPLFBranches orders branches (A.B.x or UNKNOWN) newest first, UNKNOWN last.
func CmpPLFBranches(a, b string) int {
	if a == "UNKNOWN" {
		return -strcasecmp("000", b)
	} else if b == "UNKNOWN" {
		return -strcasecmp(a, "000")
	}
	return -strcasecmp(a, b)
}

// CmpInstances orders by PRODUCT_VERSION, as strcmp.
func CmpInstances(a, b Instance) int {
	return strings.Compare(a.Str("PRODUCT_VERSION"), b.Str("PRODUCT_VERSION"))
}

// MergeInstances merges values (the decoded local instances of a server) into data.
// The inputs are not modified.
func MergeInstances(values, data *Branches) *Branches {
	result := NewBranches()
	if data != nil {
		for _, k := range data.order {
			result.set(k, data.m[k])
		}
	}
	if values != nil {
		for _, key := range values.order {
			entry := values.m[key]
			if len(entry) == 0 {
				continue
			}
			existing, ok := data.get(key)
			if !ok {
				result.set(key, entry)
				continue
			}
			merged := make([]Instance, 0, len(entry)+len(existing))
			merged = append(merged, entry...)
			merged = append(merged, existing...)
			sort.SliceStable(merged, func(i, j int) bool { return CmpInstances(merged[i], merged[j]) < 0 })
			result.set(key, merged)
		}
	}
	sort.SliceStable(result.order, func(i, j int) bool { return CmpPLFBranches(result.order[i], result.order[j]) < 0 })
	return result
}

func (b *Branches) get(k string) ([]Instance, bool) {
	if b == nil {
		return nil, false
	}
	v, ok := b.m[k]
	return v, ok
}

// fetchGlobal fetches the instances of every server: complete is false when a server did not answer.
func (s *Store) fetchGlobal(ctx context.Context) (instances *Branches, complete bool) {
	var urls []string
	for _, server := range s.cfg.Servers {
		urls = append(urls, server+"/rest/local-instances")
	}
	instances = NewBranches()
	complete = true
	fetch := s.fetch
	if fetch == nil {
		fetch = httpx.FetchParallel
	}
	for _, r := range fetch(ctx, urls, fetchTimeout) {
		var values Branches
		if r.Err != nil || json.Unmarshal(r.Body, &values) != nil {
			if r.Err != nil {
				log.Printf("instances: %s: %v", r.URL, r.Err)
			} else {
				log.Printf("instances: %s: answer is not a JSON instances list", r.URL)
			}
			complete = false
			continue
		}
		instances = MergeInstances(&values, instances)
	}
	return instances, complete
}

// refreshGlobal refreshes the global instances: fresh for 2 min, and a stale copy kept longer to
// answer immediately while this runs. An incomplete result (a server is down) never replaces a complete
// stale copy and is retried shortly.
func (s *Store) refreshGlobal(ctx context.Context) *Branches {
	instances, complete := s.fetchGlobal(ctx)
	if complete {
		s.Cache.Set("all_instances", instances, freshTTL)
		s.Cache.Set("all_instances_stale", instances, staleTTL)
		return instances
	}
	if stale := s.cachedBranches("all_instances_stale"); stale != nil {
		instances = stale
	} else {
		s.Cache.Set("all_instances_stale", instances, staleTTL)
	}
	s.Cache.Set("all_instances", instances, retryTTL)
	return instances
}

// Global returns the local instances in dev mode, else the merge of every
// ACCEPTANCE_SERVERS /rest/local-instances answer (cached). The result is shared: do not modify it.
func (s *Store) Global(ctx context.Context, o Origin) *Branches {
	if s.cfg.DevMode {
		// Emulate decode/encode with json to turn arrays into objects
		data, err := json.Marshal(s.Local(o))
		if err != nil {
			return NewBranches()
		}
		var b Branches
		if err := json.Unmarshal(data, &b); err != nil {
			return NewBranches()
		}
		return &b
	}
	if b := s.cachedBranches("all_instances"); b != nil {
		return b
	}
	if stale := s.cachedBranches("all_instances_stale"); stale != nil {
		s.Cache.RunAfterResponse("all_instances_refreshing", refreshLockTTL, func() {
			s.globalMu.Lock()
			defer s.globalMu.Unlock()
			s.refreshGlobal(context.Background())
		})
		return stale
	}
	s.globalMu.Lock()
	defer s.globalMu.Unlock()
	if b := s.cachedBranches("all_instances"); b != nil { // refreshed while we were waiting
		return b
	}
	return s.refreshGlobal(ctx)
}

// filtered fetches from the cache (unless in dev mode), otherwise pulls from
// the source and keep only the branches whose instances match (or, with exclude, do not match) the labels.
func (s *Store) filtered(cacheKey string, ttl time.Duration, source func() *Branches, labels []string, allLabels, exclude bool) *Branches {
	if !s.cfg.DevMode {
		if b := s.cachedBranches(cacheKey); b != nil {
			return b
		}
	}
	out := NewBranches()
	src := source()
	src.Each(func(branch string, list []Instance) {
		var f []Instance
		if exclude {
			f = FilterWithoutLabels(list, labels, false)
		} else {
			f = FilterWithLabels(list, labels, allLabels)
		}
		if len(f) > 0 {
			out.set(branch, f)
		}
	})
	s.Cache.Set(cacheKey, out, ttl)
	return out
}

func (s *Store) global(ctx context.Context, o Origin) func() *Branches {
	return func() *Branches { return s.Global(ctx, o) }
}

// Category getters: Global filtered by labels, with the same TTLs and caches.

func (s *Store) Dev(ctx context.Context, o Origin) *Branches {
	return s.filtered("dev_instances", 120*time.Second, s.global(ctx, o), []string{"sales", "qa", "company", "doc", "translation", "cp"}, false, true)
}

func (s *Store) SalesUser(ctx context.Context, o Origin) *Branches {
	return s.filtered("sales_user_instances", 120*time.Second, s.global(ctx, o), []string{"sales", "user"}, true, false)
}

func (s *Store) SalesDemo(ctx context.Context, o Origin) *Branches {
	return s.filtered("sales_demo_instances", 300*time.Second, s.global(ctx, o), []string{"sales", "demo"}, true, false)
}

func (s *Store) SalesEval(ctx context.Context, o Origin) *Branches {
	return s.filtered("sales_eval_instances", 300*time.Second, s.global(ctx, o), []string{"sales", "eval"}, true, false)
}

func (s *Store) QA(ctx context.Context, o Origin) *Branches {
	return s.filtered("qa_instances", 120*time.Second, s.global(ctx, o), []string{"qa"}, false, false)
}

func (s *Store) QAUser(ctx context.Context, o Origin) *Branches {
	return s.filtered("qa_user_instances", 120*time.Second, func() *Branches { return s.QA(ctx, o) }, []string{"auto"}, false, true)
}

func (s *Store) QAAuto(ctx context.Context, o Origin) *Branches {
	return s.filtered("qa_auto_instances", 120*time.Second, func() *Branches { return s.QA(ctx, o) }, []string{"auto"}, false, false)
}

func (s *Store) CP(ctx context.Context, o Origin) *Branches {
	return s.filtered("cp_instances", 300*time.Second, s.global(ctx, o), []string{"cp"}, false, false)
}

func (s *Store) Company(ctx context.Context, o Origin) *Branches {
	return s.filtered("company_instances", 500*time.Second, s.global(ctx, o), []string{"company"}, false, false)
}

func (s *Store) Doc(ctx context.Context, o Origin) *Branches {
	return s.filtered("doc_instances", 300*time.Second, s.global(ctx, o), []string{"doc"}, false, false)
}

func (s *Store) Translation(ctx context.Context, o Origin) *Branches {
	return s.filtered("translation_instances", 300*time.Second, s.global(ctx, o), []string{"translation"}, false, false)
}

// AcceptanceBranches returns the SCM_BRANCH of every instance of all servers (cached 2 min).
func (s *Store) AcceptanceBranches(ctx context.Context, o Origin) []string {
	if !s.cfg.DevMode {
		if v, ok := s.Cache.Get("acceptance_branches"); ok {
			if l, ok := v.([]string); ok && len(l) > 0 {
				return l
			}
		}
	}
	branches := []string{}
	s.Global(ctx, o).Each(func(_ string, list []Instance) {
		for _, i := range list {
			if i.Truthy("SCM_BRANCH") {
				branches = append(branches, i.Str("SCM_BRANCH"))
			}
		}
	})
	s.Cache.Set("acceptance_branches", branches, 120*time.Second)
	return branches
}

// ClearCaches drops every cached value (instances, categories, locks, ...).
func (s *Store) ClearCaches() { s.Cache.Clear() }

// CheckCaches runs on every request: when the query
// has clearCaches, empty every cache and redirect to the same URL without that parameter. It reports whether
// the request has been answered (the caller must then stop). The redirect is path-only (a forged Host
// header cannot steer it) and the audit entry is left to the caller.
func (s *Store) CheckCaches(w http.ResponseWriter, r *http.Request) bool {
	q := r.URL.Query()
	if _, ok := q["clearCaches"]; !ok {
		return false
	}
	// Not on a request another site or a sibling host makes through a visitor's browser (the servers asking for the
	// lists send no Sec-Fetch-Site): the answer is the same without the parameter.
	if site := r.Header.Get("Sec-Fetch-Site"); site == "cross-site" || site == "same-site" {
		http.Error(w, "Forbidden", http.StatusForbidden)
		return true
	}
	s.ClearCaches()
	q.Del("clearCaches")
	loc := r.URL.Path
	if len(q) > 0 {
		loc += "?" + q.Encode()
	}
	http.Redirect(w, r, loc, http.StatusFound)
	return true
}
