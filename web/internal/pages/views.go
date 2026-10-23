package pages

import (
	"embed"
	"text/template"

	"github.com/exoplatform/adt/web/internal/view"
)

//go:embed templates
var templatesFS embed.FS

// funcs are the helper functions of the page templates; each file adds its own from init().
var funcs = template.FuncMap{}

// tpl holds the HTML templates and the JS/CSS fragments of the pages (see package view).
var tpl = view.New("pages", templatesFS, funcs)
