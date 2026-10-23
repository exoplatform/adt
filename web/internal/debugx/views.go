package debugx

import (
	"embed"
	"text/template"

	"github.com/exoplatform/adt/web/internal/view"
)

//go:embed templates
var templatesFS embed.FS

// Funcs are the helper functions of the /debug templates; the files of this package add theirs from init().
var Funcs = template.FuncMap{}

// Tpl holds the HTML templates and the JS/CSS fragments of the /debug pages (see package view).
var Tpl = view.New("debugx", templatesFS, Funcs)
