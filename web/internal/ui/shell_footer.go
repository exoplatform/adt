package ui

// RemoteDebugModalHTML renders the remote debug modal. It is set from init();
// Footer writes it when Ctx.RemoteDebugModal is true.
var RemoteDebugModalHTML func() string

// Footer writes the page footer: copyright, stats link, the remote-debug modal when requested, scroll-to-top button
// and the footer script (tooltips, popovers, service worker, PWA install).
func (c *Ctx) Footer() {
	modal := ""
	if c.RemoteDebugModal && RemoteDebugModalHTML != nil {
		modal = RemoteDebugModalHTML()
	}
	c.WriteString(tpl.Must("shell_footer.tmpl", struct {
		Year  int
		Host  string
		Modal string
	}{c.now().UTC().Year(), c.Origin.Host, modal}))
}
