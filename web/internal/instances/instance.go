// Package instances models the deployment descriptors the front-end shows.
//
// An Instance is deliberately a loosely typed map keyed by the descriptor variable names
// (PRODUCT_NAME, DEPLOYMENT_STATUS, ...): that is the JSON the acceptance servers exchange through
// /rest/local-instances, and servers running different versions must interoperate.
// Typed accessors give lenient reads (a missing key is "", "0" and "" are false).
package instances

import (
	"fmt"
	"strconv"

	"github.com/exoplatform/adt/web/internal/phpx"
)

// Instance is one deployment descriptor, enriched (ages, labels, status, ...).
type Instance map[string]any

// Branches maps a PLF branch (e.g. "7.3.x") to its instances, in display order.
// Keys order matters for rendering: use Branches.Keys() rather than ranging over the map.
type Branches struct {
	order []string
	m     map[string][]Instance
}

// Str returns the value of key as a string ("" when missing, "1"/"" for booleans).
func (i Instance) Str(key string) string {
	switch v := i[key].(type) {
	case nil:
		return ""
	case string:
		return v
	case bool:
		if v {
			return "1"
		}
		return ""
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64)
	case int:
		return strconv.Itoa(v)
	case []string, []any:
		return "Array"
	default:
		return fmt.Sprint(v)
	}
}

// Has reports whether the key is present and not null.
func (i Instance) Has(key string) bool { v, ok := i[key]; return ok && v != nil }

// Truthy reports whether the value is set: missing, nil, false, 0, "" and "0" are false.
func (i Instance) Truthy(key string) bool { return phpx.Truthy(i[key]) }

// List returns a list value (DEPLOYMENT_LABELS, DEPLOYMENT_ADDONS) as strings.
func (i Instance) List(key string) []string {
	switch v := i[key].(type) {
	case []string:
		return v
	case []any:
		out := make([]string, 0, len(v))
		for _, e := range v {
			out = append(out, fmt.Sprint(e))
		}
		return out
	}
	return nil
}

// NewBranches builds an ordered branch map.
func NewBranches() *Branches { return &Branches{m: map[string][]Instance{}} }

// Add appends an instance under a branch, remembering first-seen branch order.
func (b *Branches) Add(branch string, inst Instance) {
	if _, ok := b.m[branch]; !ok {
		b.order = append(b.order, branch)
	}
	b.m[branch] = append(b.m[branch], inst)
}

// Keys returns the branches in insertion order.
func (b *Branches) Keys() []string { return b.order }

// Get returns the instances of a branch.
func (b *Branches) Get(branch string) []Instance { return b.m[branch] }

// Len is the number of branches.
func (b *Branches) Len() int { return len(b.order) }

// Set replaces the instances of a branch (appending the branch when new, keeping its position otherwise).
func (b *Branches) Set(branch string, list []Instance) { b.set(branch, list) }

func (b *Branches) set(branch string, list []Instance) {
	if _, ok := b.m[branch]; !ok {
		b.order = append(b.order, branch)
	}
	b.m[branch] = list
}

// Each calls f for every branch in display order.
func (b *Branches) Each(f func(branch string, list []Instance)) {
	for _, k := range b.order {
		f(k, b.m[k])
	}
}

// Count is the total number of instances.
func (b *Branches) Count() int {
	n := 0
	for _, l := range b.m {
		n += len(l)
	}
	return n
}
