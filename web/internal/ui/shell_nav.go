package ui

import (
	"time"
)

var navItems = []struct{ Label, URL, Icon string }{
	{"Home", "/", "fa-house"},
	{"QA", "/qa", "fa-flask"},
	{"Sales", "/sales", "fa-chart-line"},
	{"Customer Projects", "/customers", "fa-briefcase"},
	{"Company", "/company", "fa-building"},
	{"Features", "/features", "fa-code-branch"},
	{"Git Activity", "/git-activity", "fa-code-commit"},
	{"Crowdin", "/crowdin-health", "fa-language"},
	{"Servers", "/servers", "fa-server"},
}

type navLink struct{ Active, URL, Aria, Label, Icon string }

// navLinks lists the sidebar links, the current page (REQUEST_URI equal to the link URL) marked active.
func (c *Ctx) navLinks() []navLink {
	uri := c.R.RequestURI
	links := make([]navLink, 0, len(navItems))
	for _, n := range navItems {
		l := navLink{URL: n.URL, Label: n.Label, Icon: n.Icon}
		if n.URL == uri {
			l.Active, l.Aria = "active", ` aria-current="page"`
		}
		links = append(links, l)
	}
	return links
}

// Navigation writes the skip link, mobile bar (theme toggle, session menu, avatar), sidebar
// (brand, links, user block, sign-out, pin, theme, dark mode, PWA install) and their scripts.
func (c *Ctx) Navigation() {
	now := c.now()
	expiry := c.SessionExpiry()
	name := c.Identity.FullName()
	d := struct {
		Host, Name, Remaining, ExpiresAt, SignOutTitle, MobileAvatar, SidebarAvatar string
		Expiry                                                                      int64
		HasName                                                                     bool
		Links                                                                       []navLink
	}{
		Host:          c.Origin.Host,
		Name:          name,
		HasName:       name != "" && name != "0", // empty or "0"
		Expiry:        expiry,
		SignOutTitle:  "Sign out",
		MobileAvatar:  GravatarURL(c.Identity.Mail, 48),
		SidebarAvatar: GravatarURL(c.Identity.Mail, 64),
		Links:         c.navLinks(),
	}
	if expiry != 0 {
		d.Remaining = SessionRemainingLabel(expiry, now)
		d.ExpiresAt = time.Unix(expiry, 0).UTC().Format("2006-01-02 15:04")
		d.SignOutTitle += " (session expires " + d.ExpiresAt + ", " + d.Remaining + " left)"
	}
	c.WriteString(tpl.Must("shell_nav.tmpl", d))
}
