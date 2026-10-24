package ui

import (
	"net/url"

	"github.com/exoplatform/adt/web/internal/instances"
)

// CurrentPageURL returns the scheme, host[:port] and REQUEST_URI of the page being served, without the
// default port of the scheme. The edit forms post it back as the "from" field so the handler can redirect to
// the page.
func (c *Ctx) CurrentPageURL() string {
	return serverURL(c.Origin.Scheme, c.Origin.Host, c.Origin.Port) + c.R.RequestURI
}

// serverURL is scheme://host[:port], leaving the port out when it is the default one of the scheme.
func serverURL(scheme, host, port string) string {
	u := scheme + "://" + host
	if port != "" && !(scheme == "http" && port == "80") && !(scheme == "https" && port == "443") {
		u += ":" + port
	}
	return u
}

// formAction is the URL the edit forms post to: the acceptance server that hosts the instance. The page the form
// is on goes in the query as well as in the "from" field: a visitor who has no session on that server is sent to
// its login page, the POST body is lost, and the query is what brings them back to this page afterwards.
func formAction(d instances.Instance, endpoint, from string) string {
	return serverURL(safe(d.Str("ACCEPTANCE_SCHEME")), safe(d.Str("ACCEPTANCE_HOST")), safe(d.Str("ACCEPTANCE_PORT"))) +
		"/" + endpoint + "?from=" + url.QueryEscape(from)
}

// FormEditNote renders the "Edit Instance Note" modal of an instance.
//
// The field names (from, key, note) and the action (/editInstance on the instance's acceptance server) are
// shared by every acceptance server, so they accept each other's posts.
func FormEditNote(c *Ctx, d instances.Instance) string {
	return tpl.Must("form_edit_note.tmpl", struct{ ID, Action, From, Key, Product, Version, Note string }{
		modalID("edit-note-", d), formAction(d, "editInstance", c.CurrentPageURL()), c.CurrentPageURL(), d.Str("INSTANCE_KEY"),
		ProductHtmlLabel(d, true), ProductVersion(d), d.Str("INSTANCE_NOTE")})
}
