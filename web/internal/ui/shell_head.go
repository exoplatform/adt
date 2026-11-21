package ui

// Head writes the <head> content of a page (meta, links and the scripts: auto-refresh, progress bar,
// theme, sidebar, instance search and view switch). It also records the
// session. The caller writes <head> ... </head> around it.
//
// autoRefresh keeps the instances on the page up to date, in place and without a reload, when a deployment is
// announced on the live socket (and as a safety net, see static/js/autorefresh.js); pass false on pages with live-updating JS state.
func (c *Ctx) Head(title string, autoRefresh bool) {
	c.trackSession()
	c.WriteString(tpl.Must("shell_head.tmpl", struct {
		Title       string
		NoTitle     bool
		AutoRefresh bool
	}{title, title == "" || title == "0", autoRefresh})) // an empty or "0" title is no title
}
