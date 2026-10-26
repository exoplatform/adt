package ui

import (
	"regexp"
	"strconv"
	"strings"

	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/phpx"
)

// ProductInfoIcon renders the info icon with its hover popover.
func ProductInfoIcon(d instances.Instance) string {
	return tpl.Must("comp_info_icon", ProductHtmlPopover(d))
}

// DownloadIcon renders the artifact download link with its popover.
func DownloadIcon(d instances.Instance) string {
	popover := tpl.Must("comp_download_popover", struct{ GroupID, ArtifactID, Timestamp string }{
		d.Str("ARTIFACT_GROUPID"), d.Str("ARTIFACT_ARTIFACTID"), d.Str("ARTIFACT_TIMESTAMP")})
	return tpl.Must("comp_download_icon", struct{ URL, Popover string }{d.Str("ARTIFACT_DL_URL"), popover})
}

// ProductHtmlLabel renders the product label. simple ignores the branch description and the note.
func ProductHtmlLabel(d instances.Instance, simple bool) string {
	name := d.Str("PRODUCT_NAME")
	if d.Truthy("PRODUCT_DESCRIPTION") {
		name = d.Str("PRODUCT_DESCRIPTION")
	}
	id := ""
	if d.Truthy("INSTANCE_ID") {
		id = d.Str("INSTANCE_ID")
	}
	content := tpl.Must("comp_label_base", struct{ Name, ID string }{name, id})
	if !simple {
		for _, key := range []string{"BRANCH_DESC", "INSTANCE_NOTE"} {
			if d.Truthy(key) {
				content = tpl.Must("comp_label_extra", struct{ Content, Extra string }{content, d.Str(key)})
			}
		}
	}
	return content
}

// httpToHTTPS turns "http:" into "https:": only the first "http:" of a line changes.
func httpToHTTPS(u string) string { return strings.Replace(u, "http:", "https:", 1) }

// ProductOpenLink renders the link(s) opening the product URL.
func ProductOpenLink(d instances.Instance, linkText string, enforceSSL bool) string {
	ssl := d.Truthy("DEPLOYMENT_APACHE_HTTPS_ENABLED")
	var url string
	if d.Truthy("DEPLOYMENT_APACHE_VHOST_ALIAS") {
		url = "http://" + d.Str("DEPLOYMENT_APACHE_VHOST_ALIAS")
	} else {
		url = d.Str("DEPLOYMENT_URL")
	}
	if instances.IsBuyPage(d) {
		url += "/buy/"
	}
	href := url
	if enforceSSL && ssl {
		href = httpToHTTPS(url)
	}
	text := linkText
	if linkText == "" || linkText == "0" {
		text = ProductHtmlLabel(d, false)
	}
	return tpl.Must("comp_open_link", struct {
		Href, Text, HTTPSHref string
		HTTPSLink             bool
	}{href, text, httpToHTTPS(url), !enforceSSL && ssl})
}

var (
	cdModeRe   = regexp.MustCompile(`-(M(?:LT|BL)|GA)$`)
	zWildcardR = regexp.MustCompile(`^(\d+\.\d+)\.Z(?:-|$)`)
)

// ProductVersion renders the product version.
func ProductVersion(d instances.Instance) string {
	base, stamp := d.Str("BASE_VERSION"), d.Str("ARTIFACT_TIMESTAMP")
	if m := cdModeRe.FindStringSubmatch(base); m != nil {
		var tip string
		switch m[1] {
		case "MBL":
			tip = "Before latest release (milestone, RC or GA) - continuous deployment"
		case "GA":
			tip = "Latest GA release - continuous deployment"
		default:
			tip = "Latest release (milestone, RC or GA) - continuous deployment"
		}
		// Name the mode (MBL/MLT/GA) and the base version it was resolved from
		tip = "Auto " + m[1] + ": " + tip + " (base version " + phpx.Esc(base) + ")"
		// X.Y.Z-...: the Z wildcard picks the patch version among all X.Y.* releases
		if z := zWildcardR.FindStringSubmatch(base); z != nil {
			tip += " - .Z wildcard: any " + z[1] + ".x patch version"
		}
		return tpl.Must("comp_version_auto", struct{ Stamp, Tip string }{stamp, tip})
	}
	content := base
	rest := stamp
	if len(base) >= len(rest) {
		rest = ""
	} else {
		rest = rest[len(base):]
	}
	if rest != "" && rest != "0" {
		if d.Truthy("BRANCH_NAME") {
			content += "-" + d.Str("BRANCH_NAME")
		}
		content += "-SNAPSHOT"
	}
	return tpl.Must("comp_version", struct{ Stamp, Content string }{stamp, content})
}

var vhostRe = regexp.MustCompile(`https?://(.*)`)

// ProductHtmlPopover renders the product popover.
func ProductHtmlPopover(d instances.Instance) string {
	// Optional lines are shown when their value is truthy
	alias, info := "", ""
	if d.Truthy("DEPLOYMENT_APACHE_VHOST_ALIAS") {
		alias = d.Str("DEPLOYMENT_APACHE_VHOST_ALIAS")
	}
	if d.Truthy("DEPLOYMENT_INFO") {
		info = d.Str("DEPLOYMENT_INFO")
	}
	return tpl.Must("comp_popover", struct {
		Label, Version, Packaging, Database, Visibility, MongoVersion, VHost, Alias, Info string
		Public, HTTPS, ES, OnlyOffice, CMIS, Chat, ChatEmbedded, WebSocket                bool
	}{
		Label:        ProductHtmlLabel(d, false),
		Version:      d.Str("PRODUCT_VERSION"),
		Packaging:    d.Str("DEPLOYMENT_APPSRV_TYPE"),
		Database:     d.Str("DATABASE"),
		Visibility:   d.Str("DEPLOYMENT_APACHE_SECURITY"),
		MongoVersion: d.Str("DEPLOYMENT_CHAT_MONGODB_VERSION"),
		VHost:        vhostRe.ReplaceAllString(d.Str("DEPLOYMENT_URL"), "$1"),
		Alias:        alias,
		Info:         info,
		Public:       d.Str("DEPLOYMENT_APACHE_SECURITY") == "public",
		HTTPS:        d.Truthy("DEPLOYMENT_APACHE_HTTPS_ENABLED"),
		ES:           d.Truthy("DEPLOYMENT_ES_EMBEDDED"),
		OnlyOffice:   d.Truthy("DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED"),
		CMIS:         d.Truthy("DEPLOYMENT_CMISSERVER_ENABLED"),
		Chat:         d.Truthy("DEPLOYMENT_CHAT_ENABLED"),
		ChatEmbedded: d.Truthy("DEPLOYMENT_CHAT_EMBEDDED"),
		WebSocket:    d.Str("ACCEPTANCE_APACHE_VERSION_MINOR") == "2.4" && d.Truthy("DEPLOYMENT_APACHE_WEBSOCKET_ENABLED"),
	})
}

// deploymentAction is one button of the DeploymentActions group; Href and Copy are already escaped.
// A button with a Copy value copies it to the clipboard instead of following a link: used for
// addresses no application is registered to open (JMX, LDAP, SSH).
type deploymentAction struct {
	Href, Title, Icon, Copy string
	Blank                   bool
}

// DeploymentActions renders the button group of an instance.
func DeploymentActions(d instances.Instance) string {
	deploymentURL := d.Str("DEPLOYMENT_EXT_HOST")
	if hasProp(d, "DEPLOYMENT_APACHE_VHOST_ALIAS") && d.Str("DEPLOYMENT_APACHE_VHOST_ALIAS") != "" {
		deploymentURL = d.Str("DEPLOYMENT_APACHE_VHOST_ALIAS")
	}
	deploymentURL = safe(deploymentURL)
	var actions []deploymentAction
	btn := func(href, title string, blank bool, icon string) {
		actions = append(actions, deploymentAction{Href: href, Title: title, Icon: icon, Blank: blank})
	}
	copyBtn := func(text, title, icon string) {
		actions = append(actions, deploymentAction{Copy: text, Title: title, Icon: icon})
	}
	flag := func(k string) bool { return hasProp(d, k) && d.Truthy(k) }
	btn(safe(d.Str("DEPLOYMENT_LOG_APPSRV_URL")), "Instance logs", true, "fa-file-alt")
	btn(safe(d.Str("DEPLOYMENT_LOG_APACHE_URL")), "Apache logs", true, "fa-server")
	if d.Truthy("DEPLOYMENT_JMX_URL") {
		copyBtn(safe(d.Str("DEPLOYMENT_JMX_URL")), "Copy the JMX URL", "fa-chart-line")
	}
	if d.Truthy("DEPLOYMENT_LDAP_LINK") {
		copyBtn(safe(d.Str("DEPLOYMENT_LDAP_LINK")), "Copy the LDAP URL", "fa-address-book")
	}
	if flag("DEPLOYMENT_CRASH_ENABLED") {
		copyBtn("ssh -p "+safe(d.Str("DEPLOYMENT_CRASH_SSH_PORT"))+" root@"+safe(d.Str("DEPLOYMENT_EXT_HOST")), "Copy the CRaSH SSH command", "fa-terminal")
	}
	btn(safe(d.Str("DEPLOYMENT_AWSTATS_URL")), "Usage statistics", true, "fa-chart-bar")
	if flag("DEPLOYMENT_ES_ENABLED") {
		btn("http://"+deploymentURL+"/elasticsearch", "Elasticsearch", false, "fa-search")
	}
	if flag("DEPLOYMENT_MAILPIT_ENABLED") {
		btn("http://"+deploymentURL+"/mailpit/", "Mailpit", false, "fa-envelope")
	}
	if flag("DEPLOYMENT_MONGO_EXPRESS_ENABLED") {
		btn("http://"+deploymentURL+"/mongoexpress/", "Mongo Express", false, "fa-database")
	}
	if flag("DEPLOYMENT_KEYCLOAK_ENABLED") {
		btn("http://"+deploymentURL+"/auth/admin/", "Keycloak", false, "fa-key")
	}
	if flag("DEPLOYMENT_CLOUDBEAVER_ENABLED") {
		btn("http://"+deploymentURL+"/cloudbeaver/", "CloudBeaver", false, "fa-cloud")
	}
	if flag("DEPLOYMENT_LAM_ENABLED") {
		btn("http://"+deploymentURL+"/lam/", "LDAP Account Manager", false, "fa-users-gear")
	}
	if flag("DEPLOYMENT_SFTP_ENABLED") {
		btn(safe(d.Str("DEPLOYMENT_SFTP_LINK")), "SFTP", false, "fa-file-export")
	}
	if flag("DEPLOYMENT_CMISSERVER_ENABLED") {
		btn("http://"+safe(d.Str("DEPLOYMENT_EXT_HOST"))+"/cmis", "CMIS Server", false, "fa-share-alt")
	}
	if flag("DEPLOYMENT_CALDAV_ENABLED") {
		btn("http://"+deploymentURL+"/baikal", "CalDAV Server (Baikal)", false, "fa-calendar-alt")
	}
	if flag("DEPLOYMENT_FRONTAIL_ENABLED") {
		btn("http://"+deploymentURL+"/livelogs/", "Instance Live logs", true, "fa-play-circle")
	}
	return tpl.Must("comp_actions", actions)
}

// FBStatusLabel renders the feature branch status label.
func FBStatusLabel(d instances.Instance) string {
	class := ""
	switch d.Str("ACCEPTANCE_STATE") {
	case "Implementing":
		class = "bg-info"
	case "Engineering Review", "QA In Progress":
		class = "bg-warning"
	case "QA Review":
		class = "bg-secondary"
	case "QA Rejected":
		class = "bg-danger"
	case "Validated":
		class = "bg-success"
	}
	return tpl.Must("comp_fb_status", struct{ Class, State string }{class, d.Str("ACCEPTANCE_STATE")})
}

// FBScmLabel renders the feature branch SCM label.
func FBScmLabel(d instances.Instance) string {
	if d.Truthy("SCM_BRANCH") {
		b := d.Str("SCM_BRANCH")
		return tpl.Must("comp_fb_scm", struct{ Anchor, Branch string }{strings.NewReplacer("/", "-", ".", "-").Replace(b), b})
	}
	return "-"
}

// FBIssueLabel renders the feature branch issue label.
func FBIssueLabel(d instances.Instance) string {
	if d.Truthy("ISSUE_NUM") {
		return tpl.Must("comp_fb_issue", d.Str("ISSUE_NUM"))
	}
	return "-"
}

// modalID is INSTANCE_KEY with "." replaced by "_", escaped.
func modalID(prefix string, d instances.Instance) string {
	return prefix + safe(strings.ReplaceAll(d.Str("INSTANCE_KEY"), ".", "_"))
}

// EditNoteIcon renders the pencil icon followed by its modal form.
func EditNoteIcon(c *Ctx, d instances.Instance) string {
	return editIcon(modalID("edit-note-", d), "Edit note", FormEditNote(c, d))
}

// FBEditIcon renders the pencil icon followed by the feature branch modal form.
func FBEditIcon(c *Ctx, d instances.Instance) string {
	return editIcon(modalID("edit-", d), "Edit feature branch", FormEditFeatureBranch(c, d))
}

func editIcon(id, title, form string) string {
	return tpl.Must("comp_edit_icon", struct{ ID, Title, Form string }{id, title, form})
}

// FBDeployIcon renders the feature branch deploy icon.
func FBDeployIcon(d instances.Instance) string {
	if d.Has("DEPLOYMENT_BUILD_URL") {
		return tpl.Must("comp_fb_deploy_icon", d.Str("DEPLOYMENT_BUILD_URL"))
	}
	return ""
}

// RepoBranchStatus is the state of one
// repository's feature branch against its base branch.
type RepoBranchStatus struct {
	CherryCommits, BehindCommits, AheadCommits int
	HTTPURLBehind, HTTPURLAhead                string
}

// FeatureRepoBranchStatus renders the feature branch status of a repository.
func FeatureRepoBranchStatus(p RepoBranchStatus, cherryCommitsDisplay bool) string {
	if cherryCommitsDisplay {
		if p.CherryCommits > 0 {
			return tpl.Must("comp_repo_cherry_behind", p.CherryCommits)
		}
		return tpl.Must("comp_repo_cherry_ok", nil)
	}
	behindClass := ""
	if p.BehindCommits > 0 {
		behindClass = "behind"
	}
	// Ahead: more than 1 commit (the SWF one) means dev commits to backport
	var title, class, icon string
	switch {
	case p.AheadCommits > 1:
		title = strconv.Itoa(p.AheadCommits) + " commits ahead of base branch - needs backport"
		class, icon = "ahead-many", "fa-code-merge"
	case p.AheadCommits > 0:
		title = strconv.Itoa(p.AheadCommits) + " commit ahead of base branch"
		class, icon = "ahead", "fa-arrow-up"
	default:
		title = "No commit ahead of base branch (SWF commit missing)"
		class, icon = "ahead-none", "fa-arrow-up"
	}
	return tpl.Must("comp_repo_stats", struct {
		BehindURL, BehindClass, AheadURL, AheadClass, AheadTitle, AheadIcon string
		Behind, Ahead                                                       int
	}{p.HTTPURLBehind, behindClass, p.HTTPURLAhead, class, title, icon, p.BehindCommits, p.AheadCommits})
}

// BuildRestartLink renders the "restart or reset data" link, with the descriptor's
// own DEPLOYMENT_BUILD_URL when set or the fallback CI job URL.
func BuildRestartLink(d instances.Instance, fallbackURL string) string {
	url := fallbackURL
	if d.Has("DEPLOYMENT_BUILD_URL") {
		url = d.Str("DEPLOYMENT_BUILD_URL") + "/build?delay=0sec"
	}
	return tpl.Must("comp_restart_link", url)
}
