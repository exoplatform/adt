package instances

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode"
)

const localTTL = 120 * time.Second

var (
	reVersionBranch = regexp.MustCompile(`([^-]*)-(.*)-SNAPSHOT`)
	reVersionOnly   = regexp.MustCompile(`(.*)-SNAPSHOT`)
)

// Local returns the descriptors of conf/adt/*, enriched, grouped by PLF_BRANCH.
// The result is shared (cached): callers must not modify it.
func (s *Store) Local(o Origin) *Branches {
	if !s.cfg.DevMode {
		if b := s.cachedBranches("local_instances"); b != nil {
			return b
		}
	}
	s.localMu.Lock()
	defer s.localMu.Unlock()
	if !s.cfg.DevMode { // somebody may have filled it while we were waiting
		if b := s.cachedBranches("local_instances"); b != nil {
			return b
		}
	}
	b := s.loadLocal(o, time.Now().UTC())
	s.Cache.Set("local_instances", b, localTTL)
	return b
}

// cachedBranches returns the cached non-empty Branches of key.
func (s *Store) cachedBranches(key string) *Branches {
	if v, ok := s.Cache.Get(key); ok {
		if b, ok := v.(*Branches); ok && b.Len() > 0 {
			return b
		}
	}
	return nil
}

// safeKeyForPath keeps INSTANCE_KEY from escaping conf/instances and conf/features.
func safeKeyForPath(key string) bool {
	return key != "" && !strings.ContainsAny(key, "/\\\x00") && !strings.Contains(key, "..")
}

// readFileString returns the raw content of a file (trailing newline included).
func readFileString(path string) (string, bool) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", false
	}
	return string(b), true
}

// dirList lists the entries of dir in readdir order (not sorted, and the
// order of the instances in a branch follows it).
func dirList(dir string) []string {
	f, err := os.Open(dir)
	if err != nil {
		log.Printf("instances: cannot read %s: %v", dir, err)
		return nil
	}
	defer f.Close()
	names, _ := f.Readdirnames(-1)
	return names
}

func (s *Store) loadLocal(o Origin, now time.Time) *Branches {
	instances := NewBranches()
	confDir := filepath.Join(s.cfg.DataDir, "conf", "adt")
	for _, vhost := range dirList(confDir) {
		content, ok := readFileString(filepath.Join(confDir, vhost))
		if !ok {
			continue
		}
		d, err := ParseINI(content)
		if err != nil {
			// skip a broken descriptor rather than building a bogus instance out of it
			log.Printf("instances: ignoring descriptor %s: %v", vhost, err)
			continue
		}
		inst := s.enrich(Instance(d), o, now)
		branch := descStr(d, "PLF_BRANCH")
		if phpEmptyStr(branch) {
			branch = "UNKNOWN"
		}
		instances.Add(branch, inst)
	}
	return instances
}

// enrich completes one parsed descriptor.
func (s *Store) enrich(d Instance, o Origin, now time.Time) Instance {
	str := func(k string) string { return descStr(d, k) }

	// BASE_VERSION / BRANCH_NAME
	pv, hasPV := d["PRODUCT_VERSION"].(string)
	if m := reVersionBranch.FindStringSubmatch(pv); m != nil {
		d["BASE_VERSION"], d["BRANCH_NAME"] = m[1], m[2]
	} else if m := reVersionOnly.FindStringSubmatch(pv); m != nil {
		d["BASE_VERSION"], d["BRANCH_NAME"] = m[1], ""
	} else {
		if hasPV {
			d["BASE_VERSION"] = pv
		} else {
			d["BASE_VERSION"] = nil
		}
		d["BRANCH_NAME"] = ""
	}

	if phpEmptyStr(str("INSTANCE_KEY")) {
		d["INSTANCE_KEY"] = str("PRODUCT_NAME") + "-" + str("PRODUCT_VERSION")
	}
	key := str("INSTANCE_KEY")
	pathKey := safeKeyForPath(key)

	// Instance note
	if pathKey {
		if note, ok := readFileString(filepath.Join(s.cfg.DataDir, "conf", "instances", key+".note")); ok {
			d["INSTANCE_NOTE"] = note
		}
	}

	// Artifact age
	built, valid := time.Time{}, false
	if d.Truthy("ARTIFACT_DATE") {
		built, valid = parseDescriptorDate(str("ARTIFACT_DATE"))
	}
	if valid {
		days, text := ageOf(built, now)
		d["ARTIFACT_AGE_STRING"] = text
		switch {
		case days > 5:
			d["ARTIFACT_AGE_CLASS"] = "red"
		case days > 2:
			d["ARTIFACT_AGE_CLASS"] = "orange"
		default:
			d["ARTIFACT_AGE_CLASS"] = "green"
		}
	} else {
		// Release artifact (or an unreadable ARTIFACT_DATE): derive it from the version.
		for k, v := range artifactAgeFromVersion(str("ARTIFACT_TIMESTAMP")+" "+str("PRODUCT_VERSION"), now) {
			d[k] = v
		}
	}
	if !phpEmptyStr(str("DEPLOYMENT_DATE")) {
		if t, ok := parseDescriptorDate(str("DEPLOYMENT_DATE")); ok {
			_, text := ageOf(t, now)
			d["DEPLOYMENT_AGE_STRING"] = text
		} else {
			d["DEPLOYMENT_AGE_STRING"] = "-NC-"
		}
	} else {
		d["DEPLOYMENT_AGE_STRING"] = "-NC-"
	}

	// Logs URLs
	base := o.Scheme + "://" + o.Host + ":" + o.Port
	d["DEPLOYMENT_LOG_APPSRV_URL"] = base + "/logs?type=instance&file=" + str("DEPLOYMENT_LOG_PATH")
	d["DEPLOYMENT_LOG_APACHE_URL"] = base + "/logs?type=apache&file=" + s.cfg.DataDir + "/var/log/apache2/" + str("DEPLOYMENT_EXT_HOST") + "-access.log"
	d["DEPLOYMENT_AWSTATS_URL"] = base + "/stats/awstats.pl?config=" + str("DEPLOYMENT_EXT_HOST")

	// database informations
	dbType := str("DEPLOYMENT_DB_TYPE")
	switch {
	case !d.Truthy("DEPLOYMENT_DATABASE_ENABLED") || phpEmptyStr(dbType):
		d["DATABASE"] = "none"
	case dbType == "MYSQL":
		d["DATABASE"] = "mysql:5.5"
	case strings.Contains(strings.ToLower(dbType), "docker"):
		d["DATABASE"] = strings.ReplaceAll(strings.ToLower(dbType), "docker_", "") + ":" + str("DEPLOYMENT_DATABASE_VERSION")
	}

	// Chat informations
	if d.Truthy("DEPLOYMENT_CHAT_ENABLED") {
		if looseEqStrings(str("DEPLOYMENT_CHAT_MONGODB_TYPE"), "DOCKER") && d.Has("DEPLOYMENT_CHAT_MONGODB_TYPE") {
			d["CHAT_DB"] = "mongo:" + str("DEPLOYMENT_CHAT_MONGODB_VERSION")
		} else if d.Has("DEPLOYMENT_CHAT_MONGODB_PORT") && looseEqStrings(str("DEPLOYMENT_CHAT_MONGODB_PORT"), "27017") {
			d["CHAT_DB"] = "mongo:2.6"
		} else if d.Has("DEPLOYMENT_CHAT_MONGODB_PORT") && looseEqStrings(str("DEPLOYMENT_CHAT_MONGODB_PORT"), "27018") {
			d["CHAT_DB"] = "mongo:3.2"
		}
	}

	// status
	d["DEPLOYMENT_STATUS"] = "Down"
	if pid := str("DEPLOYMENT_PID_FILE"); pid != "" {
		if c, ok := readFileString(pid); ok && processIsRunning(c) {
			d["DEPLOYMENT_STATUS"] = "Up"
		}
	}

	// Deployment Labels / Addons
	d["DEPLOYMENT_LABELS"] = splitList(str("DEPLOYMENT_LABELS"))
	d["DEPLOYMENT_ADDONS"] = splitList(str("DEPLOYMENT_ADDONS"))

	// Distribution Addons
	d["PRODUCT_ADDONS_DISTRIB"] = addonsDistrib(str("PRODUCT_NAME"), str("PRODUCT_BRANCH"))

	// conf/features/<key>.*
	fileBase := filepath.Join(s.cfg.DataDir, "conf", "features", key)
	feature := func(ext string) (string, bool) {
		if !pathKey {
			return "", false
		}
		return readFileString(fileBase + "." + ext)
	}
	d["ACCEPTANCE_STATE"] = "Implementing"
	if v, ok := feature("status"); ok {
		d["ACCEPTANCE_STATE"] = v
	}
	d["SPECIFICATIONS_LINK"] = ""
	if v, ok := feature("spec"); ok {
		d["SPECIFICATIONS_LINK"] = v
	}
	d["ISSUE_NUM"] = ""
	if v, ok := feature("issue"); ok {
		d["ISSUE_NUM"] = v
	}
	d["SCM_BRANCH"] = ""
	if v, ok := feature("branch"); ok {
		d["SCM_BRANCH"] = v
	}
	d["BRANCH_DESC"] = d["BRANCH_NAME"]
	if v, ok := feature("desc"); ok {
		d["BRANCH_DESC"] = v
	}

	// Server where the instance is deployed
	d["ACCEPTANCE_SCHEME"] = o.Scheme
	d["ACCEPTANCE_HOST"] = o.Host
	d["ACCEPTANCE_PORT"] = o.Port
	// not set when the variable is missing
	d["ACCEPTANCE_APACHE_VERSION"] = envOrFalse(s.cfg.ApacheVersion)
	d["ACCEPTANCE_APACHE_VERSION_MINOR"] = envOrFalse(s.cfg.ApacheVersionMinor)
	return d
}

func envOrFalse(v string) any {
	if v == "" {
		return false
	}
	return v
}

// splitList splits a comma separated value: an empty value gives an empty list.
func splitList(v string) []string {
	if phpEmptyStr(v) {
		return []string{}
	}
	return strings.Split(v, ",")
}

// addonsDistrib is the PRODUCT_ADDONS_DISTRIB switch.
func addonsDistrib(product, branch string) string {
	for _, p := range distribAddons {
		for _, name := range p.products {
			if name != product {
				continue
			}
			for _, r := range p.rules {
				for _, b := range r.branches {
					if b == branch {
						return r.value
					}
				}
			}
			return p.dflt
		}
	}
	return distribAddonsDefault
}

// processIsRunning probes every number of the PID file content with signal 0 (EPERM still means "exists");
// no shell is involved.
func processIsRunning(pidFile string) bool {
	for _, f := range strings.FieldsFunc(pidFile, func(r rune) bool { return r == ',' || unicode.IsSpace(r) }) {
		n, err := strconv.ParseUint(f, 10, 31)
		if err != nil || n == 0 {
			continue
		}
		if err := syscall.Kill(int(n), 0); err == nil || err == syscall.EPERM {
			return true
		}
	}
	return false
}

// parseDescriptorDate reads a 'Ymd.His' date (UTC). Out-of-range fields roll over.
// ok=false when v does not parse.
func parseDescriptorDate(v string) (time.Time, bool) {
	if len(v) != 15 || v[8] != '.' {
		return time.Time{}, false
	}
	n := func(a, b int) int {
		x, err := strconv.Atoi(v[a:b])
		if err != nil || v[a] == '+' || v[a] == '-' {
			return -1
		}
		return x
	}
	y, mo, d, h, mi, sec := n(0, 4), n(4, 6), n(6, 8), n(9, 11), n(11, 13), n(13, 15)
	if y < 0 || mo < 0 || d < 0 || h < 0 || mi < 0 || sec < 0 {
		return time.Time{}, false
	}
	return time.Date(y, time.Month(mo), d, h, mi, sec, 0, time.UTC), true
}

// ageOf renders an age as whole days, else hours, else minutes.
func ageOf(from, now time.Time) (days int, text string) {
	delta := now.Sub(from)
	if delta < 0 {
		delta = -delta
	}
	days = int(delta / (24 * time.Hour))
	h := int(delta % (24 * time.Hour) / time.Hour)
	i := int(delta % time.Hour / time.Minute)
	switch {
	case days > 0:
		return days, fmt.Sprintf("%d day(s) ago", days)
	case h > 0:
		return days, fmt.Sprintf("%d hour(s) ago", h)
	}
	return days, fmt.Sprintf("%d minute(s) ago", i)
}

// artifactAgeFromVersion: release artifacts have no build date; continuous deployment versions embed the
// build day (e.g. 7.3.0-20260930), used at day precision.
func artifactAgeFromVersion(versions string, now time.Time) map[string]any {
	empty := map[string]any{"ARTIFACT_AGE_STRING": "", "ARTIFACT_AGE_CLASS": "", "ARTIFACT_AGE_TITLE": ""}
	// the first position where "-YYYYMMDD" matches, not followed by a digit
	isDigit := func(c byte) bool { return c >= '0' && c <= '9' }
	for i := 0; i+9 <= len(versions); i++ {
		if versions[i] != '-' || versions[i+1] != '2' || versions[i+2] != '0' {
			continue
		}
		ok := true
		for j := i + 1; j < i+9; j++ {
			if !isDigit(versions[j]) {
				ok = false
				break
			}
		}
		if !ok || (i+9 < len(versions) && isDigit(versions[i+9])) {
			continue
		}
		y, _ := strconv.Atoi(versions[i+1 : i+5])
		m, _ := strconv.Atoi(versions[i+5 : i+7])
		d, _ := strconv.Atoi(versions[i+7 : i+9])
		built := time.Date(y, time.Month(m), d, 0, 0, 0, 0, time.UTC)
		if m < 1 || m > 12 || d < 1 || built.Day() != d { // checkdate()
			return empty
		}
		today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
		days := int(today.Sub(built) / (24 * time.Hour))
		if days < 0 {
			days = -days
		}
		text, class := "today", "green"
		if days != 0 {
			text = strconv.Itoa(days) + " day(s) ago"
		}
		switch {
		case days > 5:
			class = "red"
		case days > 2:
			class = "orange"
		}
		return map[string]any{
			"ARTIFACT_AGE_STRING": text,
			"ARTIFACT_AGE_CLASS":  class,
			"ARTIFACT_AGE_TITLE":  "Built on " + built.Format("2006-01-02") + " (from the version)",
		}
	}
	return empty
}
