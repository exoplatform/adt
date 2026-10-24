package ui

import (
	"embed"
	"text/template"

	"github.com/exoplatform/adt/web/internal/view"
)

//go:embed templates
var templatesFS embed.FS

// funcs are the helper functions of the UI templates; each file adds its own from init().
var funcs = template.FuncMap{}

// tpl holds the HTML templates and the JS/CSS fragments of the shell and the components (see package view).
var tpl = view.New("ui", templatesFS, funcs)
