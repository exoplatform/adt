package push

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/sha256"
	"encoding/base64"
	"math/big"
	"strings"
	"testing"
	"time"
)

func dec(t *testing.T, s string) []byte {
	t.Helper()
	b, err := b64.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// RFC 8291 appendix A: the message every implementation must produce from these inputs.
func TestEncryptRFC8291Vector(t *testing.T) {
	asPriv, err := ecdh.P256().NewPrivateKey(dec(t, "yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw"))
	if err != nil {
		t.Fatal(err)
	}
	got, err := encrypt([]byte("When I grow up, I want to be a watermelon"),
		dec(t, "BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4"),
		dec(t, "BTBZMqHH6r4Tts7J_aSIgg"), asPriv, dec(t, "DGv6ra1nlYgDCS1FRnbzlw"))
	if err != nil {
		t.Fatal(err)
	}
	// the 86 bytes of header (salt, record size, key id) and the ciphertext printed in the RFC
	wantHead := dec(t, "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A")
	wantBody := dec(t, "8pfeW0KbunFT06SuDKoJH9Ql87S1QUrdirN6GcG7sFz1y1sqLgVi1VhjVkHsUoEsbI_0LpXMuGvnzQ")
	if len(got) != 86+len(wantBody) || !bytes.Equal(got[:len(wantHead)-1], wantHead[:len(wantHead)-1]) || !bytes.Equal(got[86:], wantBody) {
		t.Fatalf("message differs from RFC 8291:\n got %s", b64.EncodeToString(got))
	}
}

// A message encrypted for a browser key decrypts with the browser's private key (the receiving side of RFC 8291).
func TestEncryptRoundTrip(t *testing.T) {
	ua, _ := ecdh.P256().GenerateKey(randReader{})
	auth := bytes.Repeat([]byte{7}, 16)
	body, err := Encrypt([]byte(`{"title":"x"}`), ua.PublicKey().Bytes(), auth)
	if err != nil {
		t.Fatal(err)
	}
	salt, idlen := body[:16], int(body[20])
	asPub, err := ecdh.P256().NewPublicKey(body[21 : 21+idlen])
	if err != nil {
		t.Fatal(err)
	}
	secret, _ := ua.ECDH(asPub)
	got := decrypt(t, body[21+idlen:], secret, auth, ua.PublicKey().Bytes(), body[21:21+idlen], salt)
	if string(got) != `{"title":"x"}` {
		t.Fatalf("decrypted %q", got)
	}
	if _, err := Encrypt(make([]byte, maxPayload+1), ua.PublicKey().Bytes(), auth); err == nil {
		t.Fatal("an oversized payload was accepted")
	}
	if _, err := Encrypt([]byte("x"), ua.PublicKey().Bytes(), auth[:8]); err == nil {
		t.Fatal("a short auth secret was accepted")
	}
}

func decrypt(t *testing.T, sealed, secret, auth, uaPub, asPub, salt []byte) []byte {
	t.Helper()
	prkKey := hkdfExtract(auth, secret)
	ikm := hkdfExpand(prkKey, append(append([]byte("WebPush: info\x00"), uaPub...), asPub...), 32)
	prk := hkdfExtract(salt, ikm)
	block, _ := aes.NewCipher(hkdfExpand(prk, []byte("Content-Encoding: aes128gcm\x00"), 16))
	gcm, _ := cipher.NewGCM(block)
	plain, err := gcm.Open(nil, hkdfExpand(prk, []byte("Content-Encoding: nonce\x00"), 12), sealed, nil)
	if err != nil {
		t.Fatal(err)
	}
	if plain[len(plain)-1] != 0x02 {
		t.Fatal("missing delimiter")
	}
	return plain[:len(plain)-1]
}

func TestVAPIDAuthorization(t *testing.T) {
	k, err := newVAPIDKey()
	if err != nil {
		t.Fatal(err)
	}
	der, _ := k.marshal()
	k2, err := parseVAPIDKey(der)
	if err != nil || !k2.priv.Equal(k.priv) {
		t.Fatalf("key does not survive its file: %v", err)
	}
	now := time.Unix(1_700_000_000, 0)
	h, err := k.authorization("https://push.example", "https://adt.example", now)
	if err != nil {
		t.Fatal(err)
	}
	parts := strings.SplitN(strings.TrimPrefix(h, "vapid t="), ", k=", 2)
	if len(parts) != 2 || parts[1] != base64.RawURLEncoding.EncodeToString(k.public()) {
		t.Fatalf("header %q", h)
	}
	jwt := strings.Split(parts[0], ".")
	if len(jwt) != 3 {
		t.Fatalf("jwt %q", parts[0])
	}
	if c := string(dec(t, jwt[1])); !strings.Contains(c, `"aud":"https://push.example"`) || !strings.Contains(c, `"exp":1700043200`) {
		t.Fatalf("claims %s", c)
	}
	sig := dec(t, jwt[2])
	digest := sha256.Sum256([]byte(jwt[0] + "." + jwt[1]))
	if len(sig) != 64 || !ecdsa.Verify(&k.priv.PublicKey, digest[:], new(big.Int).SetBytes(sig[:32]), new(big.Int).SetBytes(sig[32:])) {
		t.Fatal("the signature does not verify with the public key")
	}
}
