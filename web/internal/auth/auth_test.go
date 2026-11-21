package auth

import (
	"net/http/httptest"
	"testing"
	"time"
)

func TestFromHeaders(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	r.Header.Set(HeaderUser, "jdoe")
	r.Header.Set(HeaderExpiry, "1800000000")
	id := FromHeaders(r)
	if id.User != "jdoe" || id.FullName() != "jdoe" || !id.Expiry.Equal(time.Unix(1800000000, 0)) {
		t.Errorf("unexpected identity %+v", id)
	}
	for _, bad := range []string{"", "x", "-5", "0"} {
		r.Header.Set(HeaderExpiry, bad)
		if !FromHeaders(r).Expiry.IsZero() {
			t.Errorf("expiry %q parsed", bad)
		}
	}
}

func TestSessionUserPrefersRemoteUser(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	if SessionUser(r) != "" {
		t.Error("user without headers")
	}
	r.Header.Set(HeaderSessionUser, "s")
	if SessionUser(r) != "s" {
		t.Error("session user not used")
	}
	r.Header.Set(HeaderUser, "u")
	if SessionUser(r) != "u" {
		t.Error("remote user not preferred")
	}
}

func TestContextRoundTrip(t *testing.T) {
	r := With(httptest.NewRequest("GET", "/", nil), Identity{User: "u", Name: "N"})
	if From(r).FullName() != "N" {
		t.Error("identity lost")
	}
	if From(httptest.NewRequest("GET", "/", nil)).User != "" {
		t.Error("identity from nowhere")
	}
}
