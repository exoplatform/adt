// Package push sends Web Push notifications (RFC 8030) to the browsers that asked for them: the payload is encrypted
// with aes128gcm (RFC 8291) and the request is signed with a VAPID key (RFC 8292). Only the standard library is used.
package push

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/hkdf"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/asn1"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"time"
)

var b64 = base64.RawURLEncoding

// maxPayload is what a push service must accept at least (4096 bytes of record, minus the header and the tags).
const maxPayload = 3993

// Encrypt returns the body of a push message: payload encrypted for the browser that owns the subscription keys
// (p256dh: its public key, auth: its 16-byte secret), as one aes128gcm record (RFC 8291 section 4).
func Encrypt(payload []byte, p256dh, auth []byte) ([]byte, error) {
	if len(payload) > maxPayload {
		return nil, errors.New("push: payload too large")
	}
	if len(auth) != 16 {
		return nil, errors.New("push: bad auth secret")
	}
	asPriv, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		return nil, err
	}
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return nil, err
	}
	return encrypt(payload, p256dh, auth, asPriv, salt)
}

// encrypt is Encrypt with the sender key and the salt given (RFC 8291 test vector).
func encrypt(payload, p256dh, auth []byte, asPriv *ecdh.PrivateKey, salt []byte) ([]byte, error) {
	uaPub, err := ecdh.P256().NewPublicKey(p256dh)
	if err != nil {
		return nil, fmt.Errorf("push: bad p256dh: %w", err)
	}
	asPub := asPriv.PublicKey().Bytes()
	secret, err := asPriv.ECDH(uaPub)
	if err != nil {
		return nil, err
	}
	// IKM = HKDF(auth, ecdh secret, "WebPush: info" 0x00 ua_public as_public, 32)
	prkKey, err := hkdf.Extract(sha256.New, secret, auth)
	if err != nil {
		return nil, err
	}
	keyInfo := append(append([]byte("WebPush: info\x00"), p256dh...), asPub...)
	ikm, err := hkdf.Expand(sha256.New, prkKey, string(keyInfo), 32)
	if err != nil {
		return nil, err
	}
	prk, err := hkdf.Extract(sha256.New, ikm, salt)
	if err != nil {
		return nil, err
	}
	cek, err := hkdf.Expand(sha256.New, prk, "Content-Encoding: aes128gcm\x00", 16)
	if err != nil {
		return nil, err
	}
	nonce, err := hkdf.Expand(sha256.New, prk, "Content-Encoding: nonce\x00", 12)
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(cek)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	// a single, last record: the data followed by the 0x02 delimiter
	sealed := gcm.Seal(nil, nonce, append(append([]byte(nil), payload...), 0x02), nil)
	var out bytes.Buffer
	out.Write(salt)
	_ = binary.Write(&out, binary.BigEndian, uint32(4096))
	out.WriteByte(byte(len(asPub)))
	out.Write(asPub)
	out.Write(sealed)
	return out.Bytes(), nil
}

// vapidKey is the key pair that identifies this server to the push services.
type vapidKey struct {
	priv *ecdsa.PrivateKey
}

func newVAPIDKey() (*vapidKey, error) {
	k, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, err
	}
	return &vapidKey{k}, nil
}

func (k *vapidKey) marshal() ([]byte, error) { return x509.MarshalPKCS8PrivateKey(k.priv) }

func parseVAPIDKey(der []byte) (*vapidKey, error) {
	v, err := x509.ParsePKCS8PrivateKey(der)
	if err != nil {
		return nil, err
	}
	k, ok := v.(*ecdsa.PrivateKey)
	if !ok || k.Curve != elliptic.P256() {
		return nil, errors.New("push: the VAPID key is not a P-256 key")
	}
	return &vapidKey{k}, nil
}

// public is the uncompressed point (65 bytes) the browser gives to pushManager.subscribe as applicationServerKey.
func (k *vapidKey) public() []byte {
	pub, _ := k.priv.PublicKey.ECDH()
	return pub.Bytes()
}

// authorization returns the Authorization header value for a message to a push service of origin aud.
func (k *vapidKey) authorization(aud, subject string, now time.Time) (string, error) {
	head, _ := json.Marshal(map[string]string{"typ": "JWT", "alg": "ES256"})
	claims, _ := json.Marshal(map[string]any{"aud": aud, "exp": now.Add(12 * time.Hour).Unix(), "sub": subject})
	signing := b64.EncodeToString(head) + "." + b64.EncodeToString(claims)
	digest := sha256.Sum256([]byte(signing))
	der, err := ecdsa.SignASN1(rand.Reader, k.priv, digest[:])
	if err != nil {
		return "", err
	}
	var sig struct{ R, S *big.Int }
	if _, err := asn1.Unmarshal(der, &sig); err != nil {
		return "", err
	}
	raw := make([]byte, 64)
	sig.R.FillBytes(raw[:32])
	sig.S.FillBytes(raw[32:])
	return "vapid t=" + signing + "." + b64.EncodeToString(raw) + ", k=" + b64.EncodeToString(k.public()), nil
}
