// Package config reads the process environment once.
package config

import (
	"os"
	"strings"
)

// Config is the runtime configuration of the front-end.
type Config struct {
	// DataDir is ADT_DATA: conf/adt, conf/instances, conf/features, var/log, sources, ...
	DataDir string
	// DevMode is ADT_DEV_MODE: instances come from this server only, no Apache in front.
	DevMode bool
	// Servers is ACCEPTANCE_SERVERS: base URLs of all the acceptance servers (this one included).
	Servers []string
	// ApacheVersion, ApacheVersionMinor are ADT_APACHE_VERSION[_MINOR], echoed in the descriptors.
	ApacheVersion, ApacheVersionMinor string
	// StaticDir, when set, serves ./static from disk instead of the embedded copy (development).
	StaticDir string
	// Listen is the TCP address (dev) used when Socket is empty.
	Listen string
	// Socket is the unix socket Apache proxies to (production).
	Socket string
	// SocketGroup (ADT_SOCKET_GROUP) is the group given to the socket, so Apache's workers (www-data) can
	// connect while the process keeps its own user and group; the process must be a member of it
	// (systemd: SupplementaryGroups=). Empty keeps the process group.
	SocketGroup string
	// CSP is ADT_WEB_CSP: "enforce" (default), "report-only" or "off", the Content-Security-Policy of the pages.
	CSP string
	// AcceptanceHost is ACCEPTANCE_HOST, the name of this server (its Apache virtual host).
	AcceptanceHost string
	// DevUser, DevName, DevMail fake the identity Apache would provide, in DevMode only.
	DevUser, DevName, DevMail string
}

// PrimaryFrontEnd is the public dashboard, whose pages hold the edit forms of every acceptance server. It is not in
// ACCEPTANCE_SERVERS of the servers it aggregates (they list only themselves), yet their forms are posted from it.
const PrimaryFrontEnd = "https://acceptance.exoplatform.org"

// FormServers are the servers a page may come from, or send a visitor back to, when it posts an edit form: every
// ACCEPTANCE_SERVERS entry and the primary front-end. Not for the lists that are aggregated.
func (c Config) FormServers() []string {
	return append(append([]string(nil), c.Servers...), PrimaryFrontEnd)
}

// truthy is true for 1, true, yes and on (any case): "0", "no" or "False" must not switch the development mode, which
// fakes an identity, on.
func truthy(v string) bool {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "1", "true", "yes", "on":
		return true
	}
	return false
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// FromEnv builds the configuration from the environment.
func FromEnv() Config {
	c := Config{
		DataDir:            os.Getenv("ADT_DATA"),
		DevMode:            truthy(os.Getenv("ADT_DEV_MODE")),
		AcceptanceHost:     strings.TrimSpace(os.Getenv("ACCEPTANCE_HOST")),
		ApacheVersion:      os.Getenv("ADT_APACHE_VERSION"),
		ApacheVersionMinor: os.Getenv("ADT_APACHE_VERSION_MINOR"),
		StaticDir:          os.Getenv("ADT_STATIC_DIR"),
		Listen:             env("ADT_LISTEN", "127.0.0.1:8080"),
		Socket:             os.Getenv("ADT_SOCKET"),
		SocketGroup:        os.Getenv("ADT_SOCKET_GROUP"),
		CSP:                env("ADT_WEB_CSP", "enforce"),
		DevUser:            env("ADT_DEV_USER", "dev"),
		DevName:            env("ADT_DEV_NAME", "Dev User"),
		DevMail:            env("ADT_DEV_MAIL", "dev@example.org"),
	}
	for _, s := range strings.Split(os.Getenv("ACCEPTANCE_SERVERS"), ",") {
		if s = strings.TrimSpace(s); s != "" {
			c.Servers = append(c.Servers, s)
		}
	}
	return c
}
