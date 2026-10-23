package ui

import (
	"github.com/exoplatform/adt/web/internal/gitx"
	"github.com/exoplatform/adt/web/internal/instances"
)

// fbStatuses are the options of the STATUS select, in order.
var fbStatuses = []string{"Implementing", "Engineering Review", "QA Review", "QA In Progress", "QA Rejected", "Validated", "Merged"}

// FormEditFeatureBranch renders the "Edit Feature Branch" modal of an instance.
//
// The field names (from, key, description, specifications, issue, status, branch) and the action
// (/editFeature on the instance's acceptance server) are shared by every acceptance server.
func FormEditFeatureBranch(c *Ctx, d instances.Instance) string {
	type option struct {
		Name     string
		Selected bool
	}
	product := d.Str("INSTANCE_DESCRIPTION")
	if !d.Truthy("INSTANCE_DESCRIPTION") { // ?: (Elvis) falls back on any falsy value
		product = d.Str("PRODUCT_NAME")
	}
	instanceID := ""
	if d.Truthy("INSTANCE_ID") {
		instanceID = d.Str("INSTANCE_ID")
	}
	var statuses, branches []option
	state := d.Str("ACCEPTANCE_STATE")
	for _, s := range fbStatuses {
		statuses = append(statuses, option{s, state == s})
	}
	cur := d.Str("SCM_BRANCH")
	// the names of the feature branches: cached by gitx for 5 minutes
	for _, g := range gitx.FeatureBranches(c.Cfg.DataDir, gitx.RepositoryNames()) {
		branches = append(branches, option{g.Name, cur != "" && cur != "0" && cur == g.Name})
	}
	return tpl.Must("form_edit_fb.tmpl", struct {
		ID, Action, From, Key, Product, InstanceID, Version, BranchName, Description, Specifications, Issue string
		Statuses, Branches                                                                                  []option
	}{
		modalID("edit-", d), formAction(d, "editFeature", c.CurrentPageURL()), c.CurrentPageURL(), d.Str("INSTANCE_KEY"),
		product, instanceID, d.Str("BASE_VERSION"), d.Str("BRANCH_NAME"), d.Str("BRANCH_DESC"),
		d.Str("SPECIFICATIONS_LINK"), d.Str("ISSUE_NUM"), statuses, branches})
}
