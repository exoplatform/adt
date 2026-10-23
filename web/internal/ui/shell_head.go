package ui

// Head writes the <head> content of a page (meta, links and the scripts: auto-refresh, progress bar,
// theme, sidebar, instance search and view switch). It also records the
// session. The caller writes <head> ... </head> around it.
//
// autoRefresh reloads the page every 2 minutes; pass false on pages with live-updating JS state.
func (c *Ctx) Head(title string, autoRefresh bool) {
	c.trackSession()
	c.WriteString(tpl.Must("shell_head.tmpl", struct {
		Title       string
		NoTitle     bool
		AutoRefresh bool
	}{title, title == "" || title == "0", autoRefresh})) // an empty or "0" title is no title
}
