package instances

import (
	"testing"
	"time"

	"github.com/exoplatform/adt/web/internal/config"
)

// A deployment event empties the cached lists of instances, all of them (stale copies and categories included),
// and nothing else.
func TestInvalidateInstances(t *testing.T) {
	s := NewStore(config.Config{})
	for _, k := range []string{"local_instances", "all_instances", "all_instances_stale", "qa_instances", "dev_instances", "company_instances"} {
		s.Cache.Set(k, 1, time.Minute)
	}
	s.Cache.Set("git_activity", 1, time.Minute)
	s.Cache.Set("acceptance_branches", 1, time.Minute)

	s.InvalidateInstances()

	for _, k := range []string{"local_instances", "all_instances", "all_instances_stale", "qa_instances", "dev_instances", "company_instances"} {
		if _, ok := s.Cache.Get(k); ok {
			t.Errorf("%s is still cached", k)
		}
	}
	for _, k := range []string{"git_activity", "acceptance_branches"} {
		if _, ok := s.Cache.Get(k); !ok {
			t.Errorf("%s was dropped", k)
		}
	}
}
