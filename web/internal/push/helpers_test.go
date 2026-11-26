package push

import (
	"crypto/hkdf"
	"crypto/rand"
	"crypto/sha256"
)

type randReader struct{}

func (randReader) Read(p []byte) (int, error) { return rand.Read(p) }

func hkdfExtract(salt, ikm []byte) []byte {
	b, _ := hkdf.Extract(sha256.New, ikm, salt)
	return b
}

func hkdfExpand(prk, info []byte, n int) []byte {
	b, _ := hkdf.Expand(sha256.New, prk, string(info), n)
	return b
}
