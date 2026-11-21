package sessions

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/exoplatform/adt/web/internal/auth"
)

func req(hdr map[string]string) *http.Request {
	r := httptest.NewRequest("GET", "/", nil)
	for k, v := range hdr {
		r.Header.Set(k, v)
	}
	return r
}

func TestIDFromHeaderOrCookie(t *testing.T) {
	good := strings.Repeat("ab", 20)
	if got := ID(req(map[string]string{auth.HeaderSession: strings.ToUpper(good)})); got != good {
		t.Errorf("header id = %q, want %q", got, good)
	}
	// a malformed header is ignored, never used as a file name
	for _, bad := range []string{"../../etc/passwd", "zz", good + "0", good[:39]} {
		if got := ID(req(map[string]string{auth.HeaderSession: bad})); got != "" {
			t.Errorf("malformed header %q gave id %q", bad, got)
		}
	}
	r := req(nil)
	r.AddCookie(&http.Cookie{Name: "adt_session", Value: "secret"})
	if got := ID(r); got != sha1hex("secret") || !hexIDRe.MatchString(got) {
		t.Errorf("cookie id = %q", got)
	}
	if ID(req(nil)) != "" {
		t.Error("id without header or cookie")
	}
}

func TestCSRFToken(t *testing.T) {
	s := New(t.TempDir())
	a := req(map[string]string{auth.HeaderSession: strings.Repeat("a1", 20)})
	b := req(map[string]string{auth.HeaderSession: strings.Repeat("b2", 20)})
	ta := s.CSRFToken(a)
	if ta == "" {
		t.Fatal("empty token for a session")
	}
	if !s.CheckCSRF(a, ta) {
		t.Error("own token refused")
	}
	if s.CheckCSRF(b, ta) {
		t.Error("token of another session accepted")
	}
	if s.CheckCSRF(a, "") || s.CheckCSRF(a, ta+"x") || s.CheckCSRF(a, strings.ToUpper(ta)) {
		t.Error("wrong or empty token accepted")
	}
	if s.CheckCSRF(req(nil), "") {
		t.Error("anonymous request with empty token accepted")
	}
}

func TestEvictRejectsNonHexID(t *testing.T) {
	s := New(t.TempDir())
	for _, id := range []string{"", "../x", "a/b", strings.Repeat("g", 40)} {
		if s.Evict(req(nil), id) {
			t.Errorf("Evict(%q) = true", id)
		}
	}
}
