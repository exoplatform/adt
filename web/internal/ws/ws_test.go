package ws

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// accept is the example of RFC 6455 section 1.3
const (
	rfcKey    = "dGhlIHNhbXBsZSBub25jZQ=="
	rfcAccept = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
)

func TestAcceptKey(t *testing.T) {
	sum := sha1.Sum([]byte(rfcKey + guid))
	if got := base64.StdEncoding.EncodeToString(sum[:]); got != rfcAccept {
		t.Fatalf("accept = %s", got)
	}
}

// serve runs handler on a real listener and dials it with a raw handshake.
func dial(t *testing.T, handler http.HandlerFunc, origin string) (net.Conn, *bufio.Reader, string) {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	c, err := net.Dial("tcp", strings.TrimPrefix(srv.URL, "http://"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	req := "GET /ws HTTP/1.1\r\nHost: " + strings.TrimPrefix(srv.URL, "http://") + "\r\nUpgrade: websocket\r\nConnection: keep-alive, Upgrade\r\n" +
		"Sec-WebSocket-Key: " + rfcKey + "\r\nSec-WebSocket-Version: 13\r\n"
	if origin != "" {
		req += "Origin: " + origin + "\r\n"
	}
	io.WriteString(c, req+"\r\n")
	br := bufio.NewReader(c)
	status, err := br.ReadString('\n')
	if err != nil {
		t.Fatal(err)
	}
	return c, br, status
}

func skipHeaders(t *testing.T, br *bufio.Reader) string {
	t.Helper()
	var all string
	for {
		l, err := br.ReadString('\n')
		if err != nil {
			t.Fatal(err)
		}
		if l == "\r\n" {
			return all
		}
		all += l
	}
}

func maskedFrame(op byte, payload string) []byte {
	mask := []byte{1, 2, 3, 4}
	f := []byte{0x80 | op, 0x80 | byte(len(payload))}
	f = append(f, mask...)
	for i := 0; i < len(payload); i++ {
		f = append(f, payload[i]^mask[i%4])
	}
	return f
}

func TestHandshakeSendPingClose(t *testing.T) {
	done := make(chan error, 1)
	c, br, status := dial(t, func(w http.ResponseWriter, r *http.Request) {
		conn, err := Upgrade(w, r)
		if err != nil {
			return
		}
		go func() { done <- conn.Drain(5 * time.Second) }()
		conn.Send([]byte("hello"))
		conn.Send([]byte(strings.Repeat("x", 300))) // 16-bit length
	}, "")
	if !strings.Contains(status, "101") {
		t.Fatalf("status %q", status)
	}
	if h := skipHeaders(t, br); !strings.Contains(h, "Sec-WebSocket-Accept: "+rfcAccept) {
		t.Fatalf("headers %q", h)
	}
	hdr := make([]byte, 7)
	io.ReadFull(br, hdr[:7])
	if string(hdr[:2]) != "\x81\x05" || string(hdr[2:7]) != "hello" {
		t.Fatalf("first frame %q", hdr)
	}
	big := make([]byte, 4+300)
	io.ReadFull(br, big)
	if big[0] != 0x81 || big[1] != 126 || big[2] != 1 || big[3] != 44 {
		t.Fatalf("big frame header %v", big[:4])
	}
	// a ping is answered with a pong carrying the same payload
	c.Write(maskedFrame(opPing, "hi"))
	pong := make([]byte, 4)
	io.ReadFull(br, pong)
	if pong[0] != 0x80|opPong || string(pong[2:]) != "hi" {
		t.Fatalf("pong %v", pong)
	}
	c.Write(maskedFrame(opClose, ""))
	select {
	case err := <-done:
		if err != io.EOF {
			t.Fatalf("drain ended with %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("drain did not end on close")
	}
}

func TestUnmaskedFrameIsRejected(t *testing.T) {
	done := make(chan error, 1)
	c, br, _ := dial(t, func(w http.ResponseWriter, r *http.Request) {
		conn, err := Upgrade(w, r)
		if err != nil {
			return
		}
		done <- conn.Drain(5 * time.Second)
	}, "")
	skipHeaders(t, br)
	c.Write([]byte{0x81, 0x01, 'x'}) // not masked
	select {
	case err := <-done:
		if err == nil || !strings.Contains(err.Error(), "protocol") {
			t.Fatalf("err = %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("unmasked frame accepted")
	}
}

func TestOversizedFrameIsRejected(t *testing.T) {
	done := make(chan error, 1)
	c, br, _ := dial(t, func(w http.ResponseWriter, r *http.Request) {
		conn, err := Upgrade(w, r)
		if err != nil {
			return
		}
		done <- conn.Drain(5 * time.Second)
	}, "")
	skipHeaders(t, br)
	c.Write([]byte{0x82, 0x80 | 127, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0xff, 1, 2, 3, 4})
	select {
	case err := <-done:
		if err == nil || !strings.Contains(err.Error(), "too big") {
			t.Fatalf("err = %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("huge frame accepted (would be allocated)")
	}
}

// Regression for cross-site WebSocket hijacking: a page of another site must not get a socket.
func TestCrossOriginIsRefused(t *testing.T) {
	_, _, status := dial(t, func(w http.ResponseWriter, r *http.Request) { Upgrade(w, r) }, "https://evil.example")
	if !strings.Contains(status, "403") {
		t.Fatalf("status %q", status)
	}
}

func TestSameOrigin(t *testing.T) {
	for _, c := range []struct {
		origin, host string
		ok           bool
	}{
		{"", "adt.example", true},
		{"https://adt.example", "adt.example", true},
		{"https://ADT.example", "adt.example", true},
		{"https://adt.example.evil.io", "adt.example", false},
		{"null", "adt.example", false},
		{"https://other.example", "adt.example", false},
	} {
		r := httptest.NewRequest("GET", "/ws", nil)
		r.Host = c.host
		if c.origin != "" {
			r.Header.Set("Origin", c.origin)
		}
		if SameOrigin(r) != c.ok {
			t.Errorf("origin %q host %q: want %v", c.origin, c.host, c.ok)
		}
	}
}

func TestNotAnUpgrade(t *testing.T) {
	rec := httptest.NewRecorder()
	if _, err := Upgrade(rec, httptest.NewRequest("GET", "/ws", nil)); err == nil || rec.Code != 400 {
		t.Fatalf("code %d err %v", rec.Code, err)
	}
}

// wrapped hides Hijack the way a middleware writer does; only Unwrap reaches the real one.
type wrapped struct{ http.ResponseWriter }

func (w wrapped) Unwrap() http.ResponseWriter { return w.ResponseWriter }

// Regression: the app wraps the writer (cspWriter), and a plain w.(http.Hijacker) answered "websocket unsupported".
func TestUpgradeThroughWrappedWriter(t *testing.T) {
	_, _, status := dial(t, func(w http.ResponseWriter, r *http.Request) {
		if c, err := Upgrade(wrapped{w}, r); err == nil {
			c.Close()
		}
	}, "")
	if !strings.Contains(status, "101") {
		t.Fatalf("status %q", status)
	}
}
