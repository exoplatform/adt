// Package crowdin is the server side of the Crowdin Healthcheck page: the latest GitHub Actions run of a
// workflow and, in modules.go, the discovery of the repositories
// that have the Crowdin workflows.
//
// The GitHub API allows 60 requests/hour without a token (5000 with GITHUB_TOKEN), shared with every other
// page, so results are cached for all viewers, refreshed conditionally (ETag: a 304 does not count against
// the limit) and calls stop while the remaining quota is low.
package crowdin

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/exoplatform/adt/web/internal/cache"
)

const (
	cacheTTL     = 600 * time.Second   // a result is reused this long before refreshing
	staleTTL     = 86400 * time.Second // a result is kept this long as a fallback
	quotaReserve = 10                  // requests left untouched for other pages
	limitedKey   = "github_api_limited_until"
	maxBody      = 4 << 20 // a page of 10 runs is far smaller; bounds a misbehaving peer
	timeout      = 5 * time.Second
)

var (
	nameRe     = regexp.MustCompile(`^[A-Za-z0-9_.-]+$`)
	workflowRe = regexp.MustCompile(`^[A-Za-z0-9_.-]+\.ya?ml$`)
	branchRe   = regexp.MustCompile(`^[A-Za-z0-9_./-]*$`)
)

// ValidParams is the parameter validation of the endpoint (400 when false).
func ValidParams(org, repo, workflow, branch string) bool {
	return nameRe.MatchString(org) && nameRe.MatchString(repo) && workflowRe.MatchString(workflow) && branchRe.MatchString(branch)
}

// Result is what the page script gets. Level is null when nothing is known (the page then falls back to the
// shields.io badge). Field order is the order of the JSON keys.
type Result struct {
	Level   *string `json:"level"`
	Message string  `json:"message"`
	RunURL  string  `json:"run_url,omitempty"`

	etag string
	at   time.Time
}

func level(l string) *string { return &l }

// Client reads workflow runs from the GitHub Actions API.
type Client struct {
	// BaseURL is the API root (ADT_GITHUB_API_URL, default https://api.github.com; overridden in tests).
	BaseURL string
	// Token is GITHUB_TOKEN: only ever sent in the Authorization header to BaseURL, never logged or
	// returned.
	Token string
	HTTP  *http.Client
	Cache *cache.Cache
	Now   func() time.Time

	mu    sync.Mutex
	locks map[string]*sync.Mutex
}

// NewClient builds the client from the environment (GITHUB_TOKEN, ADT_GITHUB_API_URL).
func NewClient() *Client {
	base := os.Getenv("ADT_GITHUB_API_URL")
	if base == "" {
		base = "https://api.github.com"
	}
	return &Client{BaseURL: strings.TrimRight(base, "/"), Token: os.Getenv("GITHUB_TOKEN"), Cache: cache.Default}
}

func (c *Client) now() time.Time {
	if c.Now != nil {
		return c.Now()
	}
	return time.Now()
}

func (c *Client) httpClient() *http.Client {
	if c.HTTP != nil {
		return c.HTTP
	}
	return &http.Client{
		Timeout: timeout,
		// The token must not follow a redirect to another host: the API does not redirect anyway.
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
}

// keyLock serialises the refreshes of one workflow so that concurrent viewers make one API call.
func (c *Client) keyLock(k string) *sync.Mutex {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.locks == nil {
		c.locks = map[string]*sync.Mutex{}
	}
	l := c.locks[k]
	if l == nil {
		l = &sync.Mutex{}
		c.locks[k] = l
	}
	return l
}

// RunToResult picks the most recent finished run; cancelled/skipped runs say nothing about health.
func RunToResult(runs []map[string]any) Result {
	str := func(m map[string]any, k string) string { s, _ := m[k].(string); return s }
	for _, run := range runs {
		if str(run, "status") != "completed" {
			continue
		}
		conclusion := str(run, "conclusion")
		if conclusion == "cancelled" || conclusion == "skipped" {
			continue
		}
		date := str(run, "created_at")
		if len(date) > 10 {
			date = date[:10]
		}
		suffix := " (" + str(run, "event") + ", " + date + ")"
		u := str(run, "html_url")
		switch conclusion {
		case "success":
			return Result{Level: level("ok"), Message: "passing" + suffix, RunURL: u}
		case "failure", "timed_out", "startup_failure":
			return Result{Level: level("fail"), Message: "failing" + suffix, RunURL: u}
		}
		return Result{Level: level("warn"), Message: conclusion + suffix, RunURL: u}
	}
	return Result{Level: level("unknown"), Message: "no status"}
}

// Status is the body of /crowdin-status. Parameters must have passed ValidParams.
func (c *Client) Status(ctx context.Context, org, repo, workflow, branch string) Result {
	cacheKey := "crowdin_run_" + org + "/" + repo + "/" + workflow + "/" + branch
	get := func() *Result {
		if v, ok := c.Cache.Get(cacheKey); ok {
			if r, ok := v.(Result); ok {
				return &r
			}
		}
		return nil
	}
	if cached := get(); cached != nil && c.now().Sub(cached.at) < cacheTTL {
		return *cached
	}
	l := c.keyLock(cacheKey)
	l.Lock()
	defer l.Unlock()
	cached := get()
	if cached != nil && c.now().Sub(cached.at) < cacheTTL {
		return *cached
	}
	unavailable := func(msg string) Result {
		if cached != nil {
			return *cached
		}
		return Result{Message: msg}
	}

	if v, ok := c.Cache.Get(limitedKey); ok {
		if until, _ := v.(int64); until > c.now().Unix() {
			return unavailable("GitHub API rate limit reached")
		}
	}

	u := c.BaseURL + "/repos/" + url.PathEscape(org) + "/" + url.PathEscape(repo) + "/actions/workflows/" +
		url.PathEscape(workflow) + "/runs?per_page=10&exclude_pull_requests=true"
	if branch != "" {
		u += "&branch=" + url.QueryEscape(branch)
	}
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return unavailable("GitHub API unavailable")
	}
	req.Header.Set("User-Agent", "ADT-Crowdin-Health")
	req.Header.Set("Accept", "application/vnd.github+json")
	if c.Token != "" {
		req.Header.Set("Authorization", "token "+c.Token)
	}
	if cached != nil && cached.etag != "" {
		req.Header.Set("If-None-Match", cached.etag)
	}
	resp, err := c.httpClient().Do(req)
	if err != nil {
		return unavailable("GitHub API unavailable")
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, maxBody))
	code := resp.StatusCode

	// Back off before the quota is used up (or once it is), until it resets
	remaining := -1
	if v := resp.Header.Get("X-RateLimit-Remaining"); v != "" {
		remaining, _ = strconv.Atoi(v)
	}
	reset := c.now().Unix() + 3600
	if v := resp.Header.Get("X-RateLimit-Reset"); v != "" {
		reset, _ = strconv.ParseInt(v, 10, 64)
	}
	if (remaining >= 0 && remaining <= quotaReserve) || code == 429 || (code == 403 && remaining == 0) {
		ttl := time.Duration(max(60, reset-c.now().Unix())) * time.Second
		c.Cache.Set(limitedKey, reset, ttl)
	}

	switch {
	case code == 304 && cached != nil:
		cached.at = c.now()
		c.Cache.Set(cacheKey, *cached, staleTTL)
		return *cached
	case code == 200:
		var data struct {
			WorkflowRuns *[]map[string]any `json:"workflow_runs"`
		}
		if json.Unmarshal(body, &data) == nil && data.WorkflowRuns != nil {
			r := RunToResult(*data.WorkflowRuns)
			r.etag = resp.Header.Get("ETag")
			r.at = c.now()
			c.Cache.Set(cacheKey, r, staleTTL)
			return r
		}
	case code == 404:
		// Private repo without token access, or workflow missing on GitHub
		r := Result{Level: level("unknown"), Message: "not found", at: c.now()}
		c.Cache.Set(cacheKey, r, staleTTL)
		return r
	}
	return unavailable("GitHub API unavailable")
}
