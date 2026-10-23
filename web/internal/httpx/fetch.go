// Package httpx holds the small HTTP helpers shared by the data layer.
package httpx

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"
)

// MaxBody caps what is read from one response (robustness: a misbehaving peer cannot exhaust memory).
const MaxBody = 32 << 20

// Result is the outcome of one URL of FetchParallel.
type Result struct {
	URL  string
	Body []byte
	Err  error // non-nil when the request failed, timed out, answered >= 400 or an empty body
}

// FetchParallel GETs every URL concurrently so that the wait is the slowest server
// and not the sum of all. timeout bounds each request (connect + transfer).
// Redirects are followed, HTTP errors (>= 400) and empty bodies are failures. Duplicated URLs are fetched once. The
// results come back in the order of the first occurrence of each URL.
func FetchParallel(ctx context.Context, urls []string, timeout time.Duration) []Result {
	seen := map[string]bool{}
	var uniq []string
	for _, u := range urls {
		if !seen[u] {
			seen[u] = true
			uniq = append(uniq, u)
		}
	}
	out := make([]Result, len(uniq))
	client := &http.Client{Timeout: timeout}
	var wg sync.WaitGroup
	for i, u := range uniq {
		wg.Add(1)
		go func() {
			defer wg.Done()
			out[i] = fetch(ctx, client, u)
		}()
	}
	wg.Wait()
	return out
}

func fetch(ctx context.Context, client *http.Client, u string) Result {
	r := Result{URL: u}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		r.Err = err
		return r
	}
	resp, err := client.Do(req)
	if err != nil {
		r.Err = err
		return r
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		r.Err = fmt.Errorf("HTTP %d", resp.StatusCode)
		return r
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, MaxBody+1))
	switch {
	case err != nil:
		r.Err = err
	case len(body) > MaxBody:
		r.Err = errors.New("response too large")
	case len(body) == 0:
		r.Err = errors.New("empty response")
	default:
		r.Body = body
	}
	return r
}
