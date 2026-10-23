package pages

import (
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/debugx"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/phpx"
)

// /debug-instances: deployment descriptors, status and Apache configuration of each instance.
func init() {
	app.HandleFunc("GET /debug-instances", debugInstances)
	funcs["debugXURL"] = phpx.URLEncode
}

// Hide the value of the sensitive keys of a descriptor. INSTANCE_KEY is the identifier, not a secret.
var sensitiveKey = regexp.MustCompile(`(?i)PASS(WORD|PHRASE)?|PASSWD|SECRET|TOKEN|PRIVATE|CREDENTIAL|API_?KEY|_KEY$`)

var iniKeyOrder = regexp.MustCompile(`(?m)^[ \t]*([^\s=\[;]+)[ \t]*(?:\[[^\]\r\n]*\])?[ \t]*=`)

// descriptorArray converts a parsed descriptor into an ordered array for the dump: keys in the order they
// first appear in the file, values masked.
func descriptorArray(content string, d map[string]any) debugx.Array {
	var keys []string
	seen := map[string]bool{}
	for _, m := range iniKeyOrder.FindAllStringSubmatch(content, -1) {
		if _, ok := d[m[1]]; ok && !seen[m[1]] {
			seen[m[1]] = true
			keys = append(keys, m[1])
		}
	}
	var rest []string
	for k := range d {
		if !seen[k] {
			rest = append(rest, k)
		}
	}
	sort.Strings(rest)
	keys = append(keys, rest...)
	out := make(debugx.Array, 0, len(keys))
	for _, k := range keys {
		v := d[k]
		if sensitiveKey.MatchString(k) && k != "INSTANCE_KEY" {
			if s, ok := v.(string); !ok || s != "" {
				v = "********"
			}
		}
		out = append(out, debugx.Item{Key: k, Val: iniValue(v)})
	}
	return out
}

func iniValue(v any) any {
	switch x := v.(type) {
	case map[string]any:
		keys := make([]string, 0, len(x))
		for k := range x {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		a := make(debugx.Array, 0, len(keys))
		for _, k := range keys {
			a = append(a, debugx.Item{Key: k, Val: iniValue(x[k])})
		}
		return a
	case []any:
		a := make([]any, len(x))
		for i, e := range x {
			a[i] = iniValue(e)
		}
		return debugx.List(a)
	}
	return v
}

// iniString is the string form of a descriptor value.
func iniString(d map[string]any, k string) (string, bool) {
	v, ok := d[k]
	if !ok {
		return "", false
	}
	if s, ok := v.(string); ok {
		return s, true
	}
	return "Array", true
}

func iniOr(d map[string]any, k, def string) string {
	if s, ok := iniString(d, k); ok {
		return s
	}
	return def
}

type instanceRow struct {
	key, host, product, security, deployed, file string
	up, pidKnown, https, vhost, include          bool
	descriptor                                   debugx.Array
}

// safeName reports a host name that is a plain file name (it ends up in paths).
func safeName(s string) bool {
	return s != "" && !strings.ContainsAny(s, "/\x00") && s != "." && s != ".."
}

func debugInstances(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	if dbgCheckCaches(c) {
		return
	}
	data := a.Cfg.DataDir
	confDir := data + "/conf/apache"

	var rows []instanceRow
	files, _ := filepath.Glob(data + "/conf/adt/*")
	for _, file := range files {
		raw, err := os.ReadFile(file)
		if err != nil {
			continue
		}
		d, err := instances.ParseINI(string(raw))
		if err != nil {
			continue
		}
		host := iniOr(d, "DEPLOYMENT_EXT_HOST", filepath.Base(file))
		pidFile := iniOr(d, "DEPLOYMENT_PID_FILE", "")
		pid := ""
		if pidFile != "" {
			if b, err := os.ReadFile(pidFile); err == nil {
				pid = strings.TrimSpace(string(b))
			}
		}
		up := false
		if pid != "" && len(pid) < 20 && strings.Trim(pid, "0123456789") == "" {
			if st, err := os.Stat("/proc/" + pid); err == nil && st.IsDir() {
				up = true
			}
		}
		exists := func(p string) bool { _, err := os.Stat(p); return err == nil }
		rows = append(rows, instanceRow{
			key:        iniOr(d, "INSTANCE_KEY", filepath.Base(file)),
			host:       host,
			product:    strings.TrimSpace(iniOr(d, "PRODUCT_NAME", "") + " " + iniOr(d, "PRODUCT_VERSION", "")),
			up:         up,
			pidKnown:   pidFile != "",
			security:   iniOr(d, "DEPLOYMENT_APACHE_SECURITY", "-"),
			https:      iniOr(d, "DEPLOYMENT_APACHE_HTTPS_ENABLED", "") == "true" || iniOr(d, "DEPLOYMENT_APACHE_HTTPSONLY_ENABLED", "") == "true",
			vhost:      safeName(host) && exists(confDir+"/sites-available/"+host),
			include:    safeName(host) && exists(confDir+"/includes/"+host+".include"),
			deployed:   iniOr(d, "DEPLOYMENT_DATE", ""),
			descriptor: descriptorArray(string(raw), d),
			file:       filepath.Base(file),
		})
	}
	sort.SliceStable(rows, func(i, j int) bool { return rows[i].host < rows[j].host })
	if q := strings.TrimSpace(dbgQuery(r, "q")); q != "" {
		var f []instanceRow
		for _, row := range rows {
			if strings.Contains(asciiLower(row.host+" "+row.key+" "+row.product), asciiLower(q)) {
				f = append(f, row)
			}
		}
		rows = f
	}
	issues := 0
	for _, row := range rows {
		if !row.vhost || !row.include {
			issues++
		}
	}
	q := strings.TrimSpace(dbgQuery(r, "q"))

	debugx.PageBegin(c, "instances", "Debug Instances", "Deployment descriptors, status and Apache configuration of each instance", false)
	type view struct {
		Host, Key, Product, Security, Deployed, Dump string
		Up, PidKnown, HTTPS, Vhost, Include          bool
	}
	views := make([]view, len(rows))
	for i, row := range rows {
		deployed := row.deployed
		if phpEmpty(deployed) {
			deployed = "-"
		}
		views[i] = view{row.host, row.key, row.product, row.security, deployed, debugx.Var(row.descriptor),
			row.up, row.pidKnown, row.https, row.vhost, row.include}
	}
	c.WriteString(tpl.Must("debug_instances.tmpl", map[string]any{
		"Rows":    views,
		"Issues":  issues,
		"Q":       q,
		"ConfDir": data + "/conf/adt",
	}))
	debugx.PageEnd(c)
}
