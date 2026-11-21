// Package ws is the smallest WebSocket (RFC 6455) server the dashboard needs: the server pushes text messages to
// the page, the page only answers pings and closes. It is written against the standard library to keep the module
// free of dependencies. Messages from the browser are read and dropped (limited in size); there is no
// fragmentation of what is sent, no extension and no sub-protocol.
package ws

import (
	"bufio"
	"crypto/sha1" //nolint:gosec // mandated by RFC 6455 for the handshake, not a security use
	"encoding/base64"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	guid        = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	maxFrame    = 64 << 10 // bigger frames from the browser close the connection
	writeWait   = 10 * time.Second
	opContinue  = 0x0
	opText      = 0x1
	opBinary    = 0x2
	opClose     = 0x8
	opPing      = 0x9
	opPong      = 0xA
	closeNormal = 1000
	closeAway   = 1001
	closeProto  = 1002
	closeBig    = 1009
)

// Conn is an open WebSocket. Send may be called from several goroutines.
type Conn struct {
	c  net.Conn
	br *bufio.Reader
	mu sync.Mutex // serialises the writes
}

// SameOrigin tells whether the request is allowed to open a socket: browsers always send Origin on a WebSocket
// handshake, and a page of another site must not be able to listen to the dashboard with the visitor's
// credentials (cross-site WebSocket hijacking). A request with no Origin is not a browser and is let through (the
// proxy in front has already authenticated it).
func SameOrigin(r *http.Request) bool {
	o := r.Header.Get("Origin")
	if o == "" {
		return true
	}
	u, err := url.Parse(o)
	return err == nil && u.Host != "" && strings.EqualFold(u.Host, r.Host)
}

func headerHas(h http.Header, name, token string) bool {
	for _, v := range h.Values(name) {
		for _, t := range strings.Split(v, ",") {
			if strings.EqualFold(strings.TrimSpace(t), token) {
				return true
			}
		}
	}
	return false
}

// Upgrade answers the handshake and takes the connection over. On failure it has already written the HTTP error.
func Upgrade(w http.ResponseWriter, r *http.Request) (*Conn, error) {
	key := r.Header.Get("Sec-WebSocket-Key")
	switch {
	case r.Method != http.MethodGet || !headerHas(r.Header, "Connection", "upgrade") || !headerHas(r.Header, "Upgrade", "websocket"):
		http.Error(w, "websocket upgrade expected", http.StatusBadRequest)
		return nil, errors.New("ws: not an upgrade request")
	case r.Header.Get("Sec-WebSocket-Version") != "13":
		w.Header().Set("Sec-WebSocket-Version", "13")
		http.Error(w, "unsupported websocket version", http.StatusUpgradeRequired)
		return nil, errors.New("ws: bad version")
	case key == "":
		http.Error(w, "missing key", http.StatusBadRequest)
		return nil, errors.New("ws: no key")
	case !SameOrigin(r):
		http.Error(w, "forbidden", http.StatusForbidden)
		return nil, errors.New("ws: cross-origin")
	}
	// ResponseController follows Unwrap, so a wrapped writer (CSP headers, logging...) can still be hijacked
	c, rw, err := http.NewResponseController(w).Hijack()
	if err != nil {
		http.Error(w, "websocket unsupported", http.StatusInternalServerError)
		return nil, err
	}
	sum := sha1.Sum([]byte(key + guid)) //nolint:gosec
	_ = c.SetWriteDeadline(time.Now().Add(writeWait))
	_, err = io.WriteString(rw, "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"+
		"Sec-WebSocket-Accept: "+base64.StdEncoding.EncodeToString(sum[:])+"\r\n\r\n")
	if err == nil {
		err = rw.Flush()
	}
	if err != nil {
		_ = c.Close()
		return nil, err
	}
	_ = c.SetWriteDeadline(time.Time{})
	return &Conn{c: c, br: rw.Reader}, nil
}

func (c *Conn) write(op byte, p []byte) error {
	var hdr [10]byte
	hdr[0] = 0x80 | op
	n := 2
	switch l := len(p); {
	case l < 126:
		hdr[1] = byte(l)
	case l <= 0xFFFF:
		hdr[1] = 126
		binary.BigEndian.PutUint16(hdr[2:], uint16(l))
		n = 4
	default:
		hdr[1] = 127
		binary.BigEndian.PutUint64(hdr[2:], uint64(l))
		n = 10
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	_ = c.c.SetWriteDeadline(time.Now().Add(writeWait))
	if _, err := c.c.Write(append(hdr[:n:n], p...)); err != nil {
		return err
	}
	return nil
}

// Send writes one text message.
func (c *Conn) Send(msg []byte) error { return c.write(opText, msg) }

// Ping writes a ping; the browser answers with a pong on its own.
func (c *Conn) Ping() error { return c.write(opPing, nil) }

// Close sends a close frame with code 1001 ("going away": something went wrong, or the handler ended) and drops
// the connection. The page treats it like a lost connection: it reconnects and reloads, since it may have missed
// messages.
func (c *Conn) Close() error { return c.closeWith(closeAway) }

// CloseNormal is Close with code 1000, for an end the server chose on purpose with nothing missed.
func (c *Conn) CloseNormal() error { return c.closeWith(closeNormal) }

// CloseWith is Close with another code (1008: refused by policy).
func (c *Conn) CloseWith(code uint16) error { return c.closeWith(code) }

func (c *Conn) closeWith(code uint16) error {
	_ = c.write(opClose, []byte{byte(code >> 8), byte(code)})
	return c.c.Close()
}

// Drain reads what the browser sends until the connection ends (close frame, error, or a protocol violation) and
// returns then. It answers pings. idle is how long the browser may stay silent: it answers every ping, so a
// connection that sends nothing for that long is gone (a proxy or a laptop that went to sleep).
func (c *Conn) Drain(idle time.Duration) error {
	for {
		_ = c.c.SetReadDeadline(time.Now().Add(idle))
		op, payload, err := c.readFrame()
		if err != nil {
			return err
		}
		switch op {
		case opPing:
			if err := c.write(opPong, payload); err != nil {
				return err
			}
		case opClose:
			_ = c.write(opClose, payload)
			return io.EOF
		}
	}
}

func (c *Conn) readFrame() (op byte, payload []byte, err error) {
	var h [2]byte
	if _, err = io.ReadFull(c.br, h[:]); err != nil {
		return
	}
	op = h[0] & 0x0f
	masked := h[1]&0x80 != 0
	n := uint64(h[1] & 0x7f)
	switch n {
	case 126:
		var b [2]byte
		if _, err = io.ReadFull(c.br, b[:]); err != nil {
			return
		}
		n = uint64(binary.BigEndian.Uint16(b[:]))
	case 127:
		var b [8]byte
		if _, err = io.ReadFull(c.br, b[:]); err != nil {
			return
		}
		n = binary.BigEndian.Uint64(b[:])
	}
	// RFC 6455: frames from a client are masked; control frames are short and never fragmented
	if !masked || h[0]&0x70 != 0 || (op >= opClose && (n > 125 || h[0]&0x80 == 0)) {
		_ = c.write(opClose, []byte{closeProto >> 8, closeProto & 0xff})
		return 0, nil, errors.New("ws: protocol violation")
	}
	if n > maxFrame {
		_ = c.write(opClose, []byte{closeBig >> 8, closeBig & 0xff})
		return 0, nil, errors.New("ws: frame too big")
	}
	var mask [4]byte
	if _, err = io.ReadFull(c.br, mask[:]); err != nil {
		return
	}
	payload = make([]byte, n)
	if _, err = io.ReadFull(c.br, payload); err != nil {
		return
	}
	for i := range payload {
		payload[i] ^= mask[i%4]
	}
	if op != opPing && op != opClose && op != opPong && op != opText && op != opBinary && op != opContinue {
		return 0, nil, errors.New("ws: unknown opcode")
	}
	return
}
