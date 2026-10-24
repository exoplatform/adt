package pages

import (
	"log"
	"math"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/phpx"
	"github.com/exoplatform/adt/web/internal/stats"
	"github.com/exoplatform/adt/web/internal/ui"
)

// /servers: acceptance server hardware overview and port registry.
// The live usage block is filled by /js/servers.js from /server-stats.
func init() {
	app.HandleFunc("GET /servers", serversPage)
	app.HandleFunc("GET /servers.php", func(a *app.App, w http.ResponseWriter, r *http.Request) {
		target := "/servers"
		if r.URL.RawQuery != "" {
			target += "?" + r.URL.RawQuery
		}
		http.Redirect(w, r, target, http.StatusMovedPermanently)
	})
}

type srvHostMeta struct{ css, short string }

type srvSpec struct{ hostname, alias, cpu, cores string }

// Hostname -> accent CSS class + short label (the order is the one of the cards).
var (
	srvHostMetaOrder = []string{"acceptance12.exoplatform.org", "acceptance13.exoplatform.org", "acceptance14.exoplatform.org", "acceptance15.exoplatform.org"}
	srvHostMetas     = map[string]srvHostMeta{
		"acceptance12.exoplatform.org": {"acc12", "acceptance12"},
		"acceptance13.exoplatform.org": {"acc13", "acceptance13"},
		"acceptance14.exoplatform.org": {"acc14", "acceptance14"},
		"acceptance15.exoplatform.org": {"acc15", "acceptance15"},
	}
	// Static server hardware specs.
	srvSpecs = []srvSpec{
		{"acceptance12.exoplatform.org", "acc02", "AMD Ryzen 9 5900X @ 3.7/4.8 GHz", "12 cores / 24 threads"},
		{"acceptance13.exoplatform.org", "acc03", "Xeon E2388G @ 3.2/4.6 GHz", "8 cores / 16 threads"},
		{"acceptance14.exoplatform.org", "acc04", "Xeon E2388G @ 3.2/4.6 GHz", "8 cores / 16 threads"},
		{"acceptance15.exoplatform.org", "acc05", "Xeon E2388G @ 3.2/4.6 GHz", "8 cores / 16 threads"},
	}
)

type srvCounter struct {
	nb             int
	jvmMin, jvmMax float64
}

var (
	srvFeatureBranchRe = regexp.MustCompile(`([^\-]*)\-(.*\-.*)\-SNAPSHOT`)
	srvAddonSpanRe     = regexp.MustCompile(`<span[^>]*>([^<]+)</span>`)
)

// srvJVMSizeGB sums the JVM sizes: "g" (found after the first character) adds the number,
// "m" adds number/1000, anything else is logged and ignored.
func srvJVMSizeGB(size string) (gb float64, ok bool) {
	if strings.Index(size, "g") > 0 { // strpos() is 0 (falsy) for a leading "g"
		return stats.PHPFloat(strings.ReplaceAll(size, "g", "")), true
	}
	if strings.Index(size, "m") > 0 {
		return stats.PHPFloat(strings.ReplaceAll(size, "m", "")) / 1000, true
	}
	return 0, false
}

// numberFormat1 formats a number with one decimal.
func srvNumberFormat1(f float64) string {
	r := math.Round(f*10) / 10
	s := strconv.FormatFloat(math.Abs(r), 'f', 1, 64)
	intPart, frac, _ := strings.Cut(s, ".")
	var b strings.Builder
	for i, c := range intPart {
		if i > 0 && (len(intPart)-i)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteRune(c)
	}
	out := b.String() + "." + frac
	if r < 0 {
		out = "-" + out
	}
	return out
}

// stripTags removes the tags of the product version markup.
func srvStripTags(s string) string {
	var b strings.Builder
	in := false
	for i := 0; i < len(s); i++ {
		switch {
		case in && s[i] == '>':
			in = false
		case in:
		case s[i] == '<' && i+1 < len(s) && (s[i+1] == '/' || s[i+1] == '!' || s[i+1] == '?' || (s[i+1]|0x20 >= 'a' && s[i+1]|0x20 <= 'z')):
			in = true
		default:
			b.WriteByte(s[i])
		}
	}
	return b.String()
}

// srvTrim trims spaces, tabs, newlines, carriage returns, NUL and vertical tabs.
func srvTrim(s string) string { return strings.Trim(s, " \t\n\r\x00\x0b") }

type srvChip struct{ Odd, Title, Label, Short, All string }

// srvPortChip describes a port shown as its suffix when it follows the instance prefix
// convention (25622 -> "22" for prefix 256), as the full number (highlighted) otherwise; nil without ports.
func srvPortChip(label string, ports []string, prefix string) *srvChip {
	var ps []string
	for _, p := range ports {
		if p != "" {
			ps = append(ps, p)
		}
	}
	if len(ps) == 0 {
		return nil
	}
	standard := true
	short := make([]string, len(ps))
	for i, p := range ps {
		if prefix != "" && strings.HasPrefix(p, prefix) && len(p) == len(prefix)+2 {
			short[i] = p[len(p)-2:]
			continue
		}
		standard = false
		short[i] = p
	}
	odd, note := "", ""
	if !standard {
		odd, note = " port-chip--odd", " (outside the instance prefix range)"
	}
	return &srvChip{odd, label + ": " + strings.Join(ps, " / ") + note, label, strings.Join(short, "/"), strings.Join(ps, " ")}
}

func srvPlural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

type srvCard struct {
	Css, Hostname, Alias, CPU, Cores, JvmMin, JvmMax string
	Nb                                               int
}

type srvFilterHost struct{ Host, Label string }

type srvAddons struct {
	Title, Names, Plural string
	Count                int
}

type srvRowData struct {
	Css, Key, Status, Host, DB, Prefix, HTTPPort                                    string
	StatusIcon, AppServerIcon, Label, Upgrade, Patch, Certbot, DevMode, StagingMode string
	DebugMode, Labels, Version, VersionTitle, FeatureBranch                         string
	Addons                                                                          *srvAddons
	JMX, Mongo, ES                                                                  *srvChip
}

type srvGroup struct {
	Css, Short, Plural string
	N                  int
	Rows               []srvRowData
}

func serversPage(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := ui.NewCtx(w, r, a.Cfg)
	if instancePageCheckCaches(a, c) {
		return
	}
	c.W.Header().Set("Content-Type", "text/html; charset=UTF-8")
	c.WriteString(tpl.Must("servers_open.tmpl", nil))
	c.Head("Servers", true)
	c.WriteString(tpl.Must("servers_style.tmpl", nil))
	c.Tracker("")
	c.Navigation()

	var all []instances.Instance
	if merged := a.Instances.Global(r.Context(), c.Origin); merged != nil {
		for _, k := range merged.Keys() {
			all = append(all, merged.Get(k)...)
		}
	}
	// stable sort on the HTTP port, compared as strings
	sort.SliceStable(all, func(i, j int) bool { return all[i].Str("DEPLOYMENT_HTTP_PORT") < all[j].Str("DEPLOYMENT_HTTP_PORT") })

	counters := map[string]*srvCounter{}
	for _, d := range all {
		host := d.Str("ACCEPTANCE_HOST")
		sc := counters[host]
		if sc == nil {
			sc = &srvCounter{}
			counters[host] = sc
		}
		sc.nb++
		if gb, ok := srvJVMSizeGB(d.Str("DEPLOYMENT_JVM_SIZE_MIN")); ok {
			sc.jvmMin += gb
		} else {
			log.Printf("The unit of DEPLOYMENT_JVM_SIZE_MIN is not managed (%s) (%s:%s)", d.Str("DEPLOYMENT_JVM_SIZE_MIN"), host, ui.ProductVersion(d))
		}
		if gb, ok := srvJVMSizeGB(d.Str("DEPLOYMENT_JVM_SIZE_MAX")); ok {
			sc.jvmMax += gb
		} else {
			log.Printf("The unit of DEPLOYMENT_JVM_SIZE_MAX is not managed (%s) (%s:%s)", d.Str("DEPLOYMENT_JVM_SIZE_MAX"), host, ui.ProductVersion(d))
		}
	}

	var cards []srvCard
	for _, spec := range srvSpecs {
		meta, ok := srvHostMetas[spec.hostname]
		if !ok {
			meta = srvHostMeta{"accX", spec.hostname}
		}
		counts := counters[spec.hostname]
		if counts == nil {
			counts = &srvCounter{}
		}
		cards = append(cards, srvCard{meta.css, spec.hostname, spec.alias, spec.cpu, spec.cores,
			srvNumberFormat1(counts.jvmMin), srvNumberFormat1(counts.jvmMax), counts.nb})
	}

	dbSet := map[string]bool{}
	for _, d := range all {
		dbSet[strings.ReplaceAll(d.Str("DATABASE"), ":", " ")] = true
	}
	filterDBs := make([]string, 0, len(dbSet))
	for db := range dbSet {
		filterDBs = append(filterDBs, db)
	}
	sort.Strings(filterDBs)  // ksort
	var filterHosts []string // insertion order (first appearance), then asort(SORT_NATURAL | SORT_FLAG_CASE)
	hostLabel := map[string]string{}
	for _, d := range all {
		h := d.Str("ACCEPTANCE_HOST")
		if _, ok := hostLabel[h]; !ok {
			filterHosts = append(filterHosts, h)
		}
		if m, ok := srvHostMetas[h]; ok {
			hostLabel[h] = m.short
		} else {
			hostLabel[h] = strings.ReplaceAll(h, ".exoplatform.org", "")
		}
	}
	sort.SliceStable(filterHosts, func(i, j int) bool {
		return phpx.StrNatCmp(strings.ToLower(hostLabel[filterHosts[i]]), strings.ToLower(hostLabel[filterHosts[j]])) < 0
	})
	hosts := make([]srvFilterHost, len(filterHosts))
	for i, h := range filterHosts {
		hosts[i] = srvFilterHost{h, hostLabel[h]}
	}
	sel := func(v string) string {
		if r.URL.Query().Get("status") == v {
			return " selected"
		}
		return ""
	}

	// Group rows by server host: known hosts first (card order), any other host last.
	rowsByHost := map[string][]instances.Instance{}
	var hostsSeen []string
	for _, d := range all {
		h := d.Str("ACCEPTANCE_HOST")
		if _, ok := rowsByHost[h]; !ok {
			hostsSeen = append(hostsSeen, h)
		}
		rowsByHost[h] = append(rowsByHost[h], d)
	}
	var ordered []string
	for _, h := range srvHostMetaOrder {
		if _, ok := rowsByHost[h]; ok {
			ordered = append(ordered, h)
		}
	}
	for _, h := range hostsSeen {
		if _, ok := srvHostMetas[h]; !ok {
			ordered = append(ordered, h)
		}
	}
	var groups []srvGroup
	for _, host := range ordered {
		meta, ok := srvHostMetas[host]
		if !ok {
			meta = srvHostMeta{"accX", strings.ReplaceAll(host, ".exoplatform.org", "")}
		}
		rows := rowsByHost[host]
		g := srvGroup{Css: meta.css, Short: meta.short, Plural: srvPlural(len(rows)), N: len(rows)}
		for _, d := range rows {
			g.Rows = append(g.Rows, srvRow(c, d, host, meta))
		}
		groups = append(groups, g)
	}

	c.WriteString(tpl.Must("servers.tmpl", map[string]any{
		"Cards": cards, "SelUp": sel("up"), "SelDown": sel("down"), "Hosts": hosts, "DBs": filterDBs, "Groups": groups,
	}))
	c.End()
}

func srvRow(c *ui.Ctx, d instances.Instance, host string, meta srvHostMeta) srvRowData {
	featureBranch := ""
	if m := srvFeatureBranchRe.FindStringSubmatch(d.Str("PRODUCT_VERSION")); m != nil {
		featureBranch = m[2]
	}
	// Add-ons collapsed into a single chip; names stay searchable
	var addons []string
	seen := map[string]bool{}
	for _, m := range srvAddonSpanRe.FindAllStringSubmatch(ui.AddonsTags(d), -1) {
		t := srvTrim(m[1])
		if t == "" || t == "0" || seen[t] {
			continue
		}
		seen[t] = true
		addons = append(addons, t)
	}
	prefix := d.Str("DEPLOYMENT_PORT_PREFIX")
	status := "down"
	if d.Str("DEPLOYMENT_STATUS") == "Up" {
		status = "up"
	}
	version := ui.ProductVersion(d)
	row := srvRowData{
		Css: meta.css, Key: d.Str("INSTANCE_KEY"), Status: status, Host: host,
		DB: strings.ReplaceAll(d.Str("DATABASE"), ":", " "), Prefix: prefix, HTTPPort: d.Str("DEPLOYMENT_HTTP_PORT"),
		StatusIcon: ui.StatusIcon(d), AppServerIcon: ui.AppServerIcon(d), Label: ui.ProductHtmlLabel(d, false),
		Upgrade: ui.UpgradeEligibility(d, true), Patch: ui.PatchInstallation(d, true), Certbot: ui.CertbotEnabled(d, true),
		DevMode: ui.DevModeEnabled(d, true), StagingMode: ui.StagingModeEnabled(d, true), DebugMode: ui.DebugModeEnabled(c, d, true),
		Labels: ui.Labels(d), Version: version, VersionTitle: srvStripTags(version),
		JMX:   srvPortChip("JMX", []string{d.Str("DEPLOYMENT_RMI_REG_PORT"), d.Str("DEPLOYMENT_RMI_SRV_PORT")}, prefix),
		Mongo: srvPortChip("Mongo", []string{d.Str("DEPLOYMENT_CHAT_MONGODB_PORT")}, prefix),
		ES:    srvPortChip("ES", []string{d.Str("DEPLOYMENT_ES_HTTP_PORT")}, prefix),
	}
	if len(addons) > 0 {
		esc := make([]string, len(addons))
		for i, ad := range addons {
			esc[i] = phpx.Esc(ad)
		}
		row.Addons = &srvAddons{strings.Join(esc, "<br>"), strings.Join(addons, " "), srvPlural(len(addons)), len(addons)}
	}
	if featureBranch != "" && featureBranch != "0" {
		row.FeatureBranch = featureBranch
	}
	return row
}
