package ui

import (
	"net/url"
	"regexp"
	"strings"

	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/phpx"
)

// Components of the instance tables and cards. Each function returns the markup as a string.
//
// Descriptor values that are echoed without escaping (URLs, versions, free text) go through safe():
// it escapes < > " ' only, so the output is unchanged for sane values but a value cannot
// break out of an attribute or inject a tag.

var safeChars = strings.NewReplacer("<", "&lt;", ">", "&gt;", `"`, "&quot;", "'", "&#039;")

// safe is the escaping applied to raw descriptor values: it never touches "&" (URLs keep their query
// strings), only the characters that can leave an attribute or open a tag.
func safe(s string) string { return safeChars.Replace(strings.ToValidUTF8(s, "�")) }

func init() { funcs["compSafe"] = safe }

// asciiLower lower-cases ASCII letters only.
func asciiLower(s string) string {
	b := []byte(s)
	for i, c := range b {
		if c >= 'A' && c <= 'Z' {
			b[i] = c + 32
		}
	}
	return string(b)
}

// hasProp reports whether the descriptor has the key.
func hasProp(d instances.Instance, key string) bool { _, ok := d[key]; return ok }

// BuildTableTitleDev renders the section title of a PLF branch.
func BuildTableTitleDev(branch string) string {
	// the branch is a descriptor value (also the key of a peer's answer): it is escaped where it is printed
	b := phpx.Esc(branch)
	switch branch {
	case "1.0.x", "1.1.x", "1.2.x", "1.3.x", "1.4.x", "1.5.x":
		return "Platform " + b + " based builds (Meeds)"
	case "4.0.x", "4.1.x", "4.2.x", "4.3.x", "4.4.x", "5.0.x", "5.1.x", "5.2.x", "5.3.x",
		"6.0.x", "6.1.x", "6.2.x", "6.3.x", "6.4.x", "6.5.x", "7.0.x", "7.1.x":
		return "Platform " + b + " based builds (Maintenance)"
	case "7.2.x":
		return "Platform or Meeds " + b + " based builds (Maintenance)"
	case "7.3.x":
		return "Platform or Meeds " + b + " based builds (R&D) - next product release (no date yet)"
	case "5.x":
		return "Platform " + b + " based builds (R&D) - perhaps next features ;-)"
	case "4.0.x Demo", "4.1.x Demo", "4.2.x Demo", "4.3.x Demo", "4.4.x Demo",
		"5.0.x Demo", "5.1.x Demo", "5.2.x Demo", "5.3.x Demo":
		return "Platform " + b + "s"
	case "COMPANY":
		return "Company internal projects"
	case "CODEFEST":
		return "eXo Codefest"
	case "UNKNOWN":
		return "Unclassified projects"
	}
	return "Platform " + b + " based build (Unclassified)"
}

// listOrScalar reads a descriptor value that is either an array or a single value.
func listOrScalar(d instances.Instance, key string) []string {
	switch d[key].(type) {
	case []string, []any:
		return d.List(key)
	}
	return []string{d.Str(key)}
}

// Labels renders the labels of an instance.
func Labels(d instances.Instance) string {
	var labels []string
	if hasProp(d, "DEPLOYMENT_LABELS") {
		labels = listOrScalar(d, "DEPLOYMENT_LABELS")
	}
	return tpl.Must("comp_labels", labels)
}

// AddonsTags renders the add-ons tags.
func AddonsTags(d instances.Instance) string {
	type addon struct{ Name, Version string }
	var addons []addon
	if hasProp(d, "DEPLOYMENT_ADDONS") {
		for _, l := range listOrScalar(d, "DEPLOYMENT_ADDONS") {
			name, version, ok := strings.Cut(l, ":")
			if !ok {
				version = "latest"
			}
			addons = append(addons, addon{name, version})
		}
	}
	return tpl.Must("comp_addons", struct {
		Distrib string
		Addons  []addon
	}{d.Str("PRODUCT_ADDONS_DISTRIB"), addons})
}

// AddonsDistributionTags renders the add-ons distribution tags.
func AddonsDistributionTags(d instances.Instance) string {
	return tpl.Must("comp_addons_distrib", d.Str("PRODUCT_ADDONS_DISTRIB"))
}

// FlagBadge renders a bare tooltipped icon or a badge-wrapped one when the property is set.
func FlagBadge(d instances.Instance, property, iconClass, badgeClass, tooltip string, isLabelAddon bool) string {
	if hasProp(d, property) && d.Truthy(property) {
		return tpl.Must("comp_flag_badge", struct {
			Badge                     bool
			BadgeClass, Tooltip, Icon string
		}{isLabelAddon, badgeClass, tooltip, iconClass})
	}
	return ""
}

// UpgradeEligibility renders the upgrade eligibility indicator.
func UpgradeEligibility(d instances.Instance, isLabelAddon bool) string {
	return FlagBadge(d, "INSTANCE_TOKEN", "fas fa-flag", "bg-info", "This instance is eligible for upgrades.", isLabelAddon)
}

// PatchInstallation renders the patch installation indicator.
func PatchInstallation(d instances.Instance, isLabelAddon bool) string {
	return FlagBadge(d, "DEPLOYMENT_PATCHES", "fas fa-plus-circle", "bg-success", d.Str("DEPLOYMENT_PATCHES")+" is installed on this instance.", isLabelAddon)
}

// StagingModeEnabled renders the staging mode indicator.
func StagingModeEnabled(d instances.Instance, isLabelAddon bool) string {
	return FlagBadge(d, "DEPLOYMENT_STAGING_ENABLED", "fas fa-fire", "bg-warning", "This instance is enabled with Staging mode.", isLabelAddon)
}

// DevModeEnabled renders the dev mode indicator.
func DevModeEnabled(d instances.Instance, isLabelAddon bool) string {
	return FlagBadge(d, "DEPLOYMENT_DEV_ENABLED", "fab fa-github", "bg-dark", "This instance is enabled with Dev mode.", isLabelAddon)
}

// CertbotEnabled renders the certbot indicator.
func CertbotEnabled(d instances.Instance, isLabelAddon bool) string {
	return FlagBadge(d, "DEPLOYMENT_CERTBOT_ENABLED", "fas fa-certificate", "bg-primary", "This instance SSL certificate is generated by certbot.", isLabelAddon)
}

var debugHostRe = regexp.MustCompile(`^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$`)

// DebugModeEnabled renders the debug mode indicator. When the badge is shown it asks the footer for the remote
// debug modal by setting c.RemoteDebugModal (c may be nil in tests).
func DebugModeEnabled(c *Ctx, d instances.Instance, isLabelAddon bool) string {
	badge := FlagBadge(d, "DEPLOYMENT_DEBUG_ENABLED", "fas fa-stethoscope", "bg-danger",
		"This instance is enabled with Debug mode. Click to see how to attach a debugger.", isLabelAddon)
	if badge == "" {
		return ""
	}
	// Prefer the vhost alias (the public fqdn): it is the name the TLS certificate is issued for.
	host := ""
	if hasProp(d, "DEPLOYMENT_EXT_HOST") {
		host = d.Str("DEPLOYMENT_EXT_HOST")
	}
	if hasProp(d, "DEPLOYMENT_APACHE_VHOST_ALIAS") && d.Str("DEPLOYMENT_APACHE_VHOST_ALIAS") != "" {
		host = d.Str("DEPLOYMENT_APACHE_VHOST_ALIAS")
	}
	if !debugHostRe.MatchString(host) {
		host = ""
	}
	if c != nil {
		c.RemoteDebugModal = true
	}
	return tpl.Must("comp_debug_link", struct{ Host, Badge string }{host, badge})
}

// StatusIcon renders the status icon.
func StatusIcon(d instances.Instance) string {
	return tpl.Must("comp_status_icon", d.Str("DEPLOYMENT_STATUS") == "Up")
}

// AppServerIcon renders the application server icon.
func AppServerIcon(d instances.Instance) string {
	// the full style class: a brand icon must not also carry fas (the solid font would win and draw nothing)
	icon := "fas fa-server"
	switch asciiLower(d.Str("DEPLOYMENT_APPSRV_TYPE")) {
	case "tomcat":
		icon = "fa-brands fa-java"
	case "jboss", "wildfly":
		icon = "fa-brands fa-redhat"
	}
	return tpl.Must("comp_appserver_icon", struct{ Icon, Type string }{icon, d.Str("DEPLOYMENT_APPSRV_TYPE")})
}

// SpecificationIcon renders the specification icon.
func SpecificationIcon(d instances.Instance) string {
	if link := d.Str("SPECIFICATIONS_LINK"); d.Truthy("SPECIFICATIONS_LINK") && IsWebURL(link) {
		return tpl.Must("comp_spec_icon", link)
	}
	return ""
}

// IsWebURL reports whether s is an http or https URL: the only kind of link a value that a visitor can edit may become
// (a javascript: or vscode: link is a trap).
func IsWebURL(s string) bool {
	u, err := url.Parse(strings.TrimSpace(s))
	return err == nil && (u.Scheme == "http" || u.Scheme == "https") && u.Host != ""
}

// DatabaseIcon renders the database icon.
func DatabaseIcon(d instances.Instance) string {
	types := []struct{ needle, label, color string }{
		{"mysql", "MySQL", "text-primary"},
		{"mariadb", "MariaDB", "text-success"},
		{"postgres", "PostgreSQL", "text-info"},
		{"oracle", "Oracle", "text-danger"},
		{"sqlserver", "SQL Server", "text-warning"},
		{"h2", "H2", "text-secondary"},
		{"hsql", "HSQLDB", "text-secondary"},
	}
	db := asciiLower(d.Str("DATABASE"))
	label, color, found := "", "text-secondary", false
	for _, t := range types {
		if strings.Contains(db, t.needle) {
			label, color, found = t.label, t.color, true
			break
		}
	}
	return tpl.Must("comp_database_icon", struct {
		Found, HasVersion     bool
		Color, Label, Version string
	}{found, d.Truthy("DEPLOYMENT_DATABASE_VERSION"), color, label, d.Str("DEPLOYMENT_DATABASE_VERSION")})
}

// VisibilityIcon renders the visibility icon; color "" means none.
func VisibilityIcon(d instances.Instance, color string) string {
	sec := d.Str("DEPLOYMENT_APACHE_SECURITY")
	icon := "fa-question-circle"
	switch sec {
	case "public":
		icon = "fa-globe"
	case "private":
		icon = "fa-lock"
	}
	colorClass := ""
	if color != "" && color != "0" {
		colorClass = " text-" + color
	}
	return tpl.Must("comp_visibility_icon", struct{ Icon, ColorClass, Security string }{icon, colorClass, sec})
}
