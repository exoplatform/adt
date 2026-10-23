package debugx

import "github.com/exoplatform/adt/web/internal/ui"

// Menu renders the debug menu.
func Menu(_ *ui.Ctx) string { return ui.DebugMenu() }
