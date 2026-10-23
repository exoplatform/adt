package pages

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/debugx"
)

// /debug-config: the rendered Apache configuration and the environment, secrets masked.
func init() {
	app.HandleFunc("GET /debug-config", debugConfig)
}

var (
	// Apache directives holding a secret
	secretDirective = regexp.MustCompile(`(?mi)^([ \t]*(?:AuthLDAPBindPassword|SessionCryptoPassphrase|SSLCertificateKeyFile|SetEnv[ \t]+\S*(?:PASS\w*|SECRET|TOKEN)\S*))[ \t]+.*$`)
	// KEY=value / KEY "value" style lines. Blanks and non-blank runs stay on the line, so "KEY=value" followed by
	// a newline cannot match the NEXT line and leave the value readable.
	secretLine = regexp.MustCompile(`(?mi)^([ \t]*[^\s=]*(?:PASSWORD|PASSPHRASE|SECRET|TOKEN)[^\s=]*[ \t]*[= \t][ \t]*).+$`)
	// environment variables whose value is hidden
	secretEnvName = regexp.MustCompile(`PASS(WORD|PHRASE)|SECRET|TOKEN|PRIVATE|CREDENTIAL|KEY`)
)

// maskSecrets hides the value of the secret directives/variables in a configuration text.
func maskSecrets(text string) string {
	text = secretDirective.ReplaceAllString(text, "${1} ********")
	return secretLine.ReplaceAllString(text, "${1}********")
}

// maxConfigView bounds what the page reads from one configuration file.
const maxConfigView = 4 << 20

func debugConfig(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	if dbgCheckCaches(c) {
		return
	}
	confDir := a.Cfg.DataDir + "/conf/apache"

	// Files that can be shown: the rendered Apache includes and vhosts only. The request picks a label
	// among these, it never supplies a path.
	files := map[string]string{}
	for _, d := range [][2]string{{"includes", confDir + "/includes"}, {"sites-available", confDir + "/sites-available"}, {"conf.d", confDir + "/conf.d"}} {
		matches, _ := filepath.Glob(d[1] + "/*")
		for _, f := range matches {
			if st, err := os.Stat(f); err == nil && st.Mode().IsRegular() {
				if fh, err := os.Open(f); err == nil {
					_ = fh.Close()
					files[d[0]+"/"+filepath.Base(f)] = f
				}
			}
		}
	}
	labels := make([]string, 0, len(files))
	for l := range files {
		labels = append(labels, l)
	}
	sort.Strings(labels)
	selected := dbgQuery(r, "file")
	if _, ok := files[selected]; !ok {
		selected = ""
		if _, ok := files["includes/acceptance-frontend.include"]; ok {
			selected = "includes/acceptance-frontend.include"
		} else if len(labels) > 0 {
			selected = labels[0]
		}
	}
	content, size, mtime := "", int64(0), int64(0)
	if selected != "" {
		if fh, err := os.Open(files[selected]); err == nil {
			st, _ := fh.Stat()
			buf, _ := io.ReadAll(io.LimitReader(fh, maxConfigView))
			_ = fh.Close()
			content = maskSecrets(string(buf))
			if st != nil {
				size, mtime = st.Size(), st.ModTime().Unix()
			}
		}
	}

	// Environment seen by the web server: secrets are masked
	envKeys := []string{"ADT_DATA", "ACCEPTANCE_SERVERS", "ADT_APACHE_VERSION", "ADT_APACHE_VERSION_MINOR", "ADT_DEV_MODE",
		"ACCEPTANCE_HOST", "ACCEPTANCE_SCHEME", "LDAP_ACCEPTANCE_BIND_DN", "LDAP_ACCEPTANCE_BIND_PASSWORD",
		"LDAP_ACCEPTANCE_APACHE2_ADMIN_DN", "ADT_SESSION_PASSPHRASE", "CROWD_ACCEPTANCE_APP_NAME", "CROWD_ACCEPTANCE_APP_PASSWORD"}
	type kv struct{ k, v string }
	var env []kv
	for _, k := range envKeys {
		if v, ok := os.LookupEnv(k); ok {
			if secretEnvName.MatchString(k) && v != "" {
				v = "********"
			}
			env = append(env, kv{k, v})
		}
	}

	debugx.PageBegin(c, "config", "Debug Config", "Rendered Apache configuration and environment (secrets masked)", false)
	type envRow struct {
		Key, Value string
		Empty      bool
	}
	envRows := make([]envRow, len(env))
	for i, e := range env {
		envRows[i] = envRow{e.k, e.v, e.v == ""}
	}
	c.WriteString(tpl.Must("debug_config.tmpl", map[string]any{
		"Labels":  debugOptions(labels, selected),
		"None":    selected == "",
		"ConfDir": confDir,
		"Path":    files[selected],
		"Mtime":   time.Unix(mtime, 0).UTC().Format("2006-01-02 15:04"),
		"Size":    debugx.Bytes(float64(size)),
		"Content": content,
		"Env":     envRows,
	}))
	debugx.PageEnd(c)
}
