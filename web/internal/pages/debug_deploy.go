package pages

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/debugx"
	"github.com/exoplatform/adt/web/internal/instances"
)

// /debug-deploy: instances of all the servers, the category getters and what to look at.
func init() {
	app.HandleFunc("GET /debug-deploy", debugDeploy)
}

// instanceID returns the key and the server/host an instance runs on.
func instanceID(i instances.Instance) string {
	return i.Str("INSTANCE_KEY") + "|" + i.Str("ACCEPTANCE_HOST") + "|" + i.Str("DEPLOYMENT_EXT_HOST")
}

// deploymentAgeDays returns the days since a "Ymd.His" deployment date.
func deploymentAgeDays(i instances.Instance, now time.Time) (int, bool) {
	d, err := time.Parse("20060102.150405", i.Str("DEPLOYMENT_DATE"))
	if err != nil {
		return 0, false
	}
	return int(math.Abs(now.Sub(d).Hours()) / 24), true
}

func flattenBranches(b *instances.Branches) []instances.Instance {
	var flat []instances.Instance
	if b != nil {
		b.Each(func(_ string, l []instances.Instance) { flat = append(flat, l...) })
	}
	return flat
}

// phpValue converts a decoded JSON value to ints and objects for the dump.
func phpValue(v any) any {
	switch x := v.(type) {
	case float64:
		if x == math.Trunc(x) && math.Abs(x) < 1e15 {
			return int64(x)
		}
		return x
	case map[string]any:
		keys := make([]string, 0, len(x))
		for k := range x {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		o := make(debugx.Object, 0, len(keys))
		for _, k := range keys {
			o = append(o, debugx.Item{Key: k, Val: phpValue(x[k])})
		}
		return o
	case []any:
		a := make([]any, len(x))
		for i, e := range x {
			a[i] = phpValue(e)
		}
		return debugx.List(a)
	case []string:
		a := make([]any, len(x))
		for i, e := range x {
			a[i] = e
		}
		return debugx.List(a)
	case instances.Instance:
		return phpValue(map[string]any(x))
	}
	return v
}

// categoriesDump is the dump of a getter result: branch => list of instance objects.
func categoriesDump(b *instances.Branches) debugx.Array {
	a := debugx.Array{}
	if b != nil {
		b.Each(func(k string, l []instances.Instance) {
			vals := make([]any, len(l))
			for i, in := range l {
				vals[i] = phpValue(in)
			}
			a = append(a, debugx.Item{Key: k, Val: debugx.List(vals)})
		})
	}
	return a
}

type deployServer struct {
	server  string
	code    int
	ms      float64
	count   int
	countOK bool
	bytes   int
}

func checkServer(ctx context.Context, server string) deployServer {
	url := strings.TrimRight(server, "/") + "/rest/local-instances"
	s := deployServer{server: server}
	t := time.Now()
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil); err == nil {
		if resp, err := http.DefaultClient.Do(req); err == nil {
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<20))
			_ = resp.Body.Close()
			s.code, s.bytes = resp.StatusCode, len(body)
			var decoded any
			if json.Unmarshal(body, &decoded) == nil {
				n := 0
				switch d := decoded.(type) {
				case map[string]any:
					for _, v := range d {
						switch x := v.(type) {
						case []any:
							n += len(x)
						case map[string]any:
							n += len(x)
						}
					}
					s.count, s.countOK = n, true
				case []any:
					for _, v := range d {
						if x, ok := v.([]any); ok {
							n += len(x)
						}
					}
					s.count, s.countOK = n, true
				}
			}
		}
	}
	s.ms = float64(time.Since(t).Microseconds()) / 1000
	return s
}

func debugDeploy(a *app.App, w http.ResponseWriter, r *http.Request) {
	c := dbgCtx(a, w, r)
	if dbgCheckCaches(c) {
		return
	}
	ctx, o, st := r.Context(), c.Origin, a.Instances
	now := time.Now()

	getters := []struct {
		name, short, rule string
		get               func(context.Context, instances.Origin) *instances.Branches
	}{
		{"getGlobalDevInstances", "Dev", "everything but sales, qa, company, doc, translation and cp", st.Dev},
		{"getGlobalQAInstances", "QA", "qa", st.QA},
		{"getGlobalQAUserInstances", "QAUser", "qa + user", st.QAUser},
		{"getGlobalQAAutoInstances", "QAAuto", "qa + auto", st.QAAuto},
		{"getGlobalCPInstances", "CP", "cp", st.CP},
		{"getGlobalCompanyInstances", "Company", "company", st.Company},
		{"getGlobalDocInstances", "Doc", "doc", st.Doc},
		{"getGlobalTranslationInstances", "Translation", "translation", st.Translation},
		{"getGlobalSalesUserInstances", "SalesUser", "sales + user", st.SalesUser},
		{"getGlobalSalesDemoInstances", "SalesDemo", "sales + demo", st.SalesDemo},
		{"getGlobalSalesEvalInstances", "SalesEval", "sales + eval", st.SalesEval},
	}

	t := time.Now()
	all := st.Global(ctx, o)
	allMs := float64(time.Since(t).Microseconds()) / 1000
	flat := flattenBranches(all)

	type result struct {
		rule, short string
		cats        *instances.Branches
		list        []instances.Instance
		ms          float64
	}
	var results []result
	membership := map[string][]string{}
	for _, g := range getters {
		t := time.Now()
		by := g.get(ctx, o)
		ms := float64(time.Since(t).Microseconds()) / 1000
		list := flattenBranches(by)
		for _, i := range list {
			membership[instanceID(i)] = append(membership[instanceID(i)], g.short)
		}
		results = append(results, result{g.rule, g.name, by, list, ms})
	}
	shortOf := map[string]string{}
	for _, g := range getters {
		shortOf[g.name] = g.short
	}

	// problems
	type problem struct{ level, name, text string }
	var problems []problem
	seen := map[string]bool{}
	for _, i := range flat {
		id := instanceID(i)
		name := i.Str("INSTANCE_KEY")
		if phpEmpty(name) {
			name = i.Str("DEPLOYMENT_EXT_HOST")
		}
		if seen[id] {
			problems = append(problems, problem{"warning", name, "listed twice (same key and host)"})
		}
		seen[id] = true
		if i.Str("DEPLOYMENT_STATUS") == "Down" {
			problems = append(problems, problem{"danger", name, "is down"})
		}
		if age, ok := deploymentAgeDays(i, now); ok && age > 30 {
			problems = append(problems, problem{"warning", name, fmt.Sprintf("was last deployed %d days ago", age)})
		}
		if i.Str("ARTIFACT_AGE_CLASS") == "red" {
			problems = append(problems, problem{"warning", name, "runs an artifact older than 5 days (" + i.Str("ARTIFACT_AGE_STRING") + ")"})
		}
		if i.Str("DEPLOYMENT_EXT_HOST") == "" || i.Str("INSTANCE_KEY") == "" {
			n := name
			if phpEmpty(n) {
				n = "?"
			}
			problems = append(problems, problem{"danger", n, "has no INSTANCE_KEY or DEPLOYMENT_EXT_HOST"})
		}
		if len(membership[id]) == 0 {
			problems = append(problems, problem{"info", name, "is not returned by any category getter (not shown in any dashboard section)"})
		}
	}

	// instances explorer (filtered)
	q := strings.TrimSpace(dbgQuery(r, "q"))
	statusFilter := dbgQuery(r, "status")
	var explorer []instances.Instance
	for _, i := range flat {
		if statusFilter != "" && i.Str("DEPLOYMENT_STATUS") != statusFilter {
			continue
		}
		hay := i.Str("INSTANCE_KEY") + " " + i.Str("DEPLOYMENT_EXT_HOST") + " " + i.Str("PRODUCT_VERSION") + " " + i.Str("ACCEPTANCE_HOST") + " " + strings.Join(i.List("DEPLOYMENT_LABELS"), " ")
		if q == "" || strings.Contains(asciiLower(hay), asciiLower(q)) {
			explorer = append(explorer, i)
		}
	}
	sort.SliceStable(explorer, func(x, y int) bool {
		return explorer[x].Str("DEPLOYMENT_EXT_HOST") < explorer[y].Str("DEPLOYMENT_EXT_HOST")
	})

	// servers check, on demand (network calls)
	_, wantServers := r.URL.Query()["servers"]
	var servers []deployServer
	if wantServers {
		for _, s := range a.Cfg.Servers {
			servers = append(servers, checkServer(ctx, s))
		}
	}

	up, down := 0, 0
	for _, i := range flat {
		switch i.Str("DEPLOYMENT_STATUS") {
		case "Up":
			up++
		case "Down":
			down++
		}
	}
	serverCount := max(1, len(a.Cfg.Servers))
	source := "live fetch"
	if os.Getenv("ADT_DEV_MODE") != "" && os.Getenv("ADT_DEV_MODE") != "0" {
		source = "local instances (ADT_DEV_MODE)"
	} else if _, ok := cache.Default.Get("all_instances"); ok {
		source = "fresh cache"
	} else if _, ok := cache.Default.Get("all_instances_stale"); ok {
		source = "stale cache"
	}

	debugx.PageBegin(c, "deployment", "Debug Deployment", "Instances of all the servers, category getters and what to look at", false)
	itoa := strconv.Itoa
	round := func(f float64) string { return strconv.FormatInt(int64(math.Round(f)), 10) }
	or := func(s, def string) string {
		if phpEmpty(s) {
			return def
		}
		return s
	}

	type serverRow struct {
		Server, Class, Code, Ms, Size string
		Count                         int
		CountOK                       bool
	}
	var serverRows []serverRow
	for _, s := range servers {
		cls, code := "bg-danger", "no answer"
		if s.code == 200 && s.countOK {
			cls = "bg-success"
		}
		if s.code != 0 {
			code = itoa(s.code)
		}
		serverRows = append(serverRows, serverRow{s.server, cls, code, round(s.ms), debugx.Bytes(float64(s.bytes)), s.count, s.countOK})
	}
	serversAlert := ""
	if wantServers && len(servers) == 0 {
		serversAlert = debugx.Alert("secondary", "ACCEPTANCE_SERVERS is not set: only this server is used.")
	}

	type problemRow struct{ Level, Name, Text string }
	problemRows := make([]problemRow, len(problems))
	for i, p := range problems {
		problemRows[i] = problemRow{p.level, p.name, p.text}
	}

	type item struct{ Desc, Host string }
	type category struct {
		Name  string
		Items []item
	}
	type getterRow struct {
		Short, Rule, Ms, Dump string
		N, CatCount, Count    int
		Cats                  []category
	}
	getterRows := make([]getterRow, len(results))
	for n, res := range results {
		g := getterRow{Short: res.short, Rule: res.rule, Ms: round(res.ms), N: n + 1, CatCount: res.cats.Len(), Count: len(res.list)}
		if len(res.list) > 0 {
			res.cats.Each(func(cat string, l []instances.Instance) {
				items := make([]item, len(l))
				for k, i := range l {
					items[k] = item{or(i.Str("INSTANCE_DESCRIPTION"), i.Str("INSTANCE_KEY")), i.Str("DEPLOYMENT_EXT_HOST")}
				}
				g.Cats = append(g.Cats, category{cat, items})
			})
			g.Dump = debugx.VarToggle(categoriesDump(res.cats))
		}
		getterRows[n] = g
	}

	type explorerRow struct {
		Host, Key, Server, Version, Status, Badge, Artifact, Deployed, Listed string
		Labels                                                                []string
	}
	explorerRows := make([]explorerRow, len(explorer))
	for k, i := range explorer {
		st := i.Str("DEPLOYMENT_STATUS")
		badge := "bg-secondary"
		switch st {
		case "Up":
			badge = "bg-success"
		case "Down":
			badge = "bg-danger"
		}
		explorerRows[k] = explorerRow{i.Str("DEPLOYMENT_EXT_HOST"), i.Str("INSTANCE_KEY"), i.Str("ACCEPTANCE_HOST"), i.Str("PRODUCT_VERSION"),
			or(st, "?"), badge, or(i.Str("ARTIFACT_AGE_STRING"), "-"), or(i.Str("DEPLOYMENT_AGE_STRING"), "-"),
			strings.Join(membership[instanceID(i)], ", "), i.List("DEPLOYMENT_LABELS")}
	}

	c.WriteString(tpl.Must("debug_deploy.tmpl", map[string]any{
		"Total":        len(flat),
		"Up":           up,
		"Down":         down,
		"ServerCount":  serverCount,
		"Source":       source,
		"AllMs":        round(allMs),
		"Problems":     problemRows,
		"Servers":      serverRows,
		"ServersAlert": serversAlert,
		"Getters":      getterRows,
		"Explorer":     explorerRows,
		"Q":            q,
		"Statuses":     debugOptions([]string{"Up", "Down"}, statusFilter),
	}))
	debugx.PageEnd(c)
}
