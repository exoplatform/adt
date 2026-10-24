package ui

// DefaultTrackerID is the Google Analytics id Tracker uses when none is given.
const DefaultTrackerID = "UA-1292368-28"

// Tracker writes the Google Analytics snippet. Use DefaultTrackerID (or "" for it).
func (c *Ctx) Tracker(id string) {
	if id == "" {
		id = DefaultTrackerID
	}
	c.WriteString(tpl.Must("shell_tracker.tmpl", struct{ ID string }{id}))
}
