package pages

import (
	"net/http"
	"strings"

	"github.com/exoplatform/adt/web/internal/app"
	"github.com/exoplatform/adt/web/internal/cache"
	"github.com/exoplatform/adt/web/internal/instances"
	"github.com/exoplatform/adt/web/internal/ui"
)

// Helpers shared by the instance-card pages (index, qa, sales, customers, company).

// instancePageCheckCaches handles "?clearCaches": it audits, clears the caches and
// redirects to the same page without the parameter. It reports whether the request was answered.
//
// A request the browser marks as cross-site is refused, since a page on another site could otherwise make a
// signed-in visitor force a refetch from every acceptance server. The redirect is path-only and drops the
// parameter whatever its value.
func instancePageCheckCaches(a *app.App, c *ui.Ctx) bool {
	q := c.R.URL.Query()
	if _, ok := q["clearCaches"]; !ok {
		return false
	}
	if crossSite(c.R) {
		http.Error(c.W, "Forbidden", http.StatusForbidden)
		return true
	}
	c.Audit.Add(c.R, "cache.clear", "page", c.R.URL.Path)
	a.Instances.ClearCaches()
	cache.InvalidateAll()
	q.Del("clearCaches")
	loc := c.R.URL.Path
	if len(q) > 0 {
		loc += "?" + q.Encode()
	}
	http.Redirect(c.W, c.R, loc, http.StatusFound)
	return true
}

// ciACC is the start of the CI job URLs used as fallback restart links.
const ciACC = "https://ci.exoplatform.org/view/°%20ACCEPTANCE%20°/job/"

// eachInstance walks the instances of every branch in display order.
func eachInstance(b *instances.Branches, f func(branch string, inst instances.Instance)) {
	for _, br := range b.Keys() {
		for _, inst := range b.Get(br) {
			f(br, inst)
		}
	}
}

// listSection is one titled grid of instance cards, rendered by the list_section template.
type listSection struct{ Icon, Title, Cards string }

// listCards renders the card of every instance of b, in display order, one after the other.
func listCards(b *instances.Branches, card func(inst instances.Instance) string) string {
	var sb strings.Builder
	eachInstance(b, func(_ string, inst instances.Instance) { sb.WriteString(card(inst)) })
	return sb.String()
}

// listSectionOf is the section of b, or nil when b holds no instance.
func listSectionOf(b *instances.Branches, icon, title string, card func(inst instances.Instance) string) *listSection {
	if !instances.InCategory(b) {
		return nil
	}
	return &listSection{icon, title, listCards(b, card)}
}
