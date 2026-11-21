package pages

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/config"
)

func postFeature(t *testing.T, a *app.App, form url.Values) *httptest.ResponseRecorder {
	t.Helper()
	r := httptest.NewRequest("POST", "/editFeature", strings.NewReader(form.Encode()))
	r.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	r.Header.Set("Sec-Fetch-Site", "same-origin")
	w := httptest.NewRecorder()
	a.Handler().ServeHTTP(w, r)
	return w
}

// The issue key of a feature goes into the path of a link to the community site and the status is one of the options of the form:
// what climbs in a path ("../x", "?", "#", "/") or is not a status is refused, nothing is written.
func TestEditFeatureValidatesIssueAndStatus(t *testing.T) {
	dir := t.TempDir()
	a := app.New(config.Config{DevMode: true, DevUser: "dev", DataDir: dir})
	file := filepath.Join(dir, "conf", "features", "plf-7.3.x.issue")

	for _, bad := range []string{"../../x?y", "123/../../a", "12#3", "a b", "x?y=1", "../..", "..", strings.Repeat("A", 41), "ok\nnewline", "<b>x</b>"} {
		w := postFeature(t, a, url.Values{"key": {"plf-7.3.x"}, "issue": {bad}, "status": {"Merged"}})
		if w.Code != http.StatusBadRequest {
			t.Errorf("issue %q: %d, want 400", bad, w.Code)
		}
		if _, err := os.Stat(file); err == nil {
			t.Fatalf("issue %q was written", bad)
		}
	}
	for _, bad := range []string{"Hacked", "merged", "Implementing<script>"} {
		if w := postFeature(t, a, url.Values{"key": {"plf-7.3.x"}, "issue": {"MEED-1234"}, "status": {bad}}); w.Code != http.StatusBadRequest {
			t.Errorf("status %q: %d, want 400", bad, w.Code)
		}
	}
	for _, good := range []string{"MEED-1234", "12345", "task_7.1", ""} {
		w := postFeature(t, a, url.Values{"key": {"plf-7.3.x"}, "issue": {good}, "status": {"QA Review"}})
		if w.Code != http.StatusFound {
			t.Errorf("issue %q: %d, want 302", good, w.Code)
		}
	}
	got, err := os.ReadFile(file)
	if err == nil && string(got) != "task_7.1" && string(got) != "" {
		t.Errorf("stored %q", got)
	}
}
