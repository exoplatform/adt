package instances

// Predicates and label filters over instances.

import "strings"

// labelValues returns the DEPLOYMENT_LABELS list, or a
// one-element list holding a non-list value (a string coming from a server that did not split it).
// present=false when the instance has no DEPLOYMENT_LABELS property.
func labelValues(i Instance) (vals []any, present bool) {
	v, ok := i["DEPLOYMENT_LABELS"]
	if !ok {
		return nil, false
	}
	switch x := v.(type) {
	case []string:
		out := make([]any, len(x))
		for k, s := range x {
			out[k] = s
		}
		return out, true
	case []any:
		return x, true
	}
	return []any{v}, true
}

func inArrayLoose(label string, vals []any) bool {
	for _, v := range vals {
		if looseEqAny(label, v) {
			return true
		}
	}
	return false
}

// HasLabels reports whether the instance has at least one of the labels (all of them when all is true).
// Quirks kept: a missing DEPLOYMENT_LABELS or an empty list is false, a string value counts as one label
// (so "sales,demo" is not split), and an empty label list is false.
func HasLabels(i Instance, labels []string, all bool) bool {
	vals, present := labelValues(i)
	if !present || len(vals) == 0 {
		return false
	}
	result := false
	for _, label := range labels {
		has := inArrayLoose(label, vals)
		switch {
		case all && !has:
			return false
		case all && has:
			result = true
		case !all && has:
			return true
		default:
			result = false
		}
	}
	return result
}

// FilterWithLabels keeps the instances that have the labels.
func FilterWithLabels(in []Instance, labels []string, all bool) []Instance {
	out := []Instance{}
	for _, i := range in {
		if HasLabels(i, labels, all) {
			out = append(out, i)
		}
	}
	return out
}

// FilterWithoutLabels keeps the instances that do not have the labels.
func FilterWithoutLabels(in []Instance, labels []string, all bool) []Instance {
	out := []Instance{}
	for _, i := range in {
		if !HasLabels(i, labels, all) {
			out = append(out, i)
		}
	}
	return out
}

// InCategory reports whether the map holds at least one instance (an object with INSTANCE_KEY).
func InCategory(b *Branches) bool {
	if b == nil {
		return false
	}
	for _, k := range b.Keys() {
		for _, i := range b.Get(k) {
			if _, ok := i["INSTANCE_KEY"]; ok {
				return true
			}
		}
	}
	return false
}

// IsFeatureBranch reports whether the branch name is not a translation one, or the fb label is set.
func IsFeatureBranch(i Instance) bool {
	if i.Truthy("BRANCH_NAME") && !strings.Contains(i.Str("BRANCH_NAME"), "translation") {
		return true
	}
	return HasLabels(i, []string{"fb"}, false)
}

// IsTranslation is true when the instance has the "translation" label; BRANCH_NAME is not tested.
func IsTranslation(i Instance) bool { return HasLabels(i, []string{"translation"}, false) }

func IsDoc(i Instance) bool     { return HasLabels(i, []string{"doc"}, false) }
func IsBuyPage(i Instance) bool { return HasLabels(i, []string{"buy"}, false) }
func IsQA(i Instance) bool      { return HasLabels(i, []string{"qa"}, false) }
func IsCompany(i Instance) bool { return HasLabels(i, []string{"company"}, false) }

// Branch name helpers (git branches of the sources, not descriptors).

// IsFeature reports whether the branch is a feature branch: all feature branches must be on the origin (SWF-2520).
func IsFeature(branch string) bool { return strings.Contains(branch, "origin/feature/") }

// IsTranslationBranch reports whether the branch is an integration translation branch.
func IsTranslationBranch(branch string) bool {
	return strings.Contains(branch, "translation") && strings.Contains(branch, "origin/integration")
}

// IsBackup reports whether the branch is a backup or temporary one.
func IsBackup(branch string) bool {
	return strings.Contains(branch, "backup") || strings.Contains(branch, "tmp") || strings.Contains(branch, "temp")
}
