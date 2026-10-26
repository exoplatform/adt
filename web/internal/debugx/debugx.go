package debugx

import (
	"fmt"
	"math"
	"math/rand/v2"
	"strconv"
	"strings"

	"github.com/exoplatform/adt/web/internal/ui"
)

// Bytes formats a byte count: "1.5G", "512B".
func Bytes(n float64) string {
	units := []string{"B", "K", "M", "G", "T"}
	i := 0
	for n >= 1024 && i < len(units)-1 {
		n /= 1024
		i++
	}
	if i == 0 {
		return fmt.Sprintf("%d%s", int64(n), units[i])
	}
	return fmt.Sprintf("%.1f%s", n, units[i])
}

// Alert renders a Bootstrap alert, the message is escaped.
func Alert(kind, message string) string {
	return Tpl.Must("debug_alert.tmpl", map[string]string{"Kind": kind, "Message": message})
}

// Open writes the opening shared by the debug pages that do not use PageBegin:
// <html><head> head </head><body> tracker, navigation (no doctype).
func Open(c *ui.Ctx, title string, autoRefresh bool) {
	c.W.Header().Set("Content-Type", "text/html; charset=UTF-8")
	c.WriteString("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n")
	c.Head(title, autoRefresh)
	c.WriteString("</head>\n<body>\n")
	c.Tracker("")
	c.Navigation()
}

// PageBegin writes Open, the page title block and the debug menu. Close with PageEnd.
func PageBegin(c *ui.Ctx, title, heading, subtitle string, autoRefresh bool) {
	Open(c, "debug - "+title, autoRefresh)
	c.WriteString(Tpl.Must("debug_page_begin.tmpl", map[string]string{"Heading": heading, "Subtitle": subtitle}))
	c.WriteString(Menu(c))
}

// PageEnd closes the page opened by PageBegin.
func PageEnd(c *ui.Ctx) {
	c.WriteString(`</div></div></div></div></div>`)
	c.Footer()
	c.WriteString(`</body></html>`)
}

// Item is one entry of an Array or an Object: Key is a string or an int.
type Item struct{ Key, Val any }

// Array is an ordered key/value list for VarExport.
type Array []Item

// Object is a stdClass for VarExport.
type Object []Item

// List is an Array with keys 0, 1, 2...
func List[T any](vals []T) Array {
	a := make(Array, len(vals))
	for i, v := range vals {
		a[i] = Item{i, v}
	}
	return a
}

// VarExport returns an indented text dump of v (nested arrays and objects).
func VarExport(v any) string {
	var b strings.Builder
	export(&b, v, 1)
	return b.String()
}

func spaces(b *strings.Builder, n int) { b.WriteString(strings.Repeat(" ", n)) }

func quote(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `'`, `\'`)
	s = strings.ReplaceAll(s, "\x00", `' . "\0" . '`)
	return "'" + s + "'"
}

func key(k any) string {
	if s, ok := k.(string); ok {
		return quote(s)
	}
	return fmt.Sprint(k)
}

func export(b *strings.Builder, v any, level int) {
	switch x := v.(type) {
	case nil:
		b.WriteString("NULL")
	case bool:
		b.WriteString(strconv.FormatBool(x))
	case int:
		b.WriteString(strconv.Itoa(x))
	case int64:
		b.WriteString(strconv.FormatInt(x, 10))
	case float64:
		s := strconv.FormatFloat(x, 'g', -1, 64)
		if !math.IsInf(x, 0) && !math.IsNaN(x) && !strings.ContainsAny(s, ".eE") {
			s += ".0"
		}
		b.WriteString(s)
	case string:
		b.WriteString(quote(x))
	case []string:
		export(b, List(x), level)
	case []any:
		export(b, List(x), level)
	case Array:
		if level > 1 {
			b.WriteString("\n")
			spaces(b, level-1)
		}
		b.WriteString("array (\n")
		for _, it := range x {
			spaces(b, level+1)
			b.WriteString(key(it.Key) + " => ")
			export(b, it.Val, level+2)
			b.WriteString(",\n")
		}
		if level > 1 {
			spaces(b, level-1)
		}
		b.WriteString(")")
	case Object:
		if level > 1 {
			b.WriteString("\n")
			spaces(b, level-1)
		}
		b.WriteString("(object) array(\n")
		for _, it := range x {
			spaces(b, level+2)
			b.WriteString(key(it.Key) + " => ")
			export(b, it.Val, level+2)
			b.WriteString(",\n")
		}
		if level > 1 {
			spaces(b, level-1)
		}
		b.WriteString(")")
	default:
		b.WriteString(quote(fmt.Sprint(v)))
	}
}

// Var is the dump of v in a <pre>.
func Var(v any) string {
	return Tpl.Must("debug_var.tmpl", VarExport(v))
}

// VarToggle is a "Toggle Details" button and the collapsed dump. The id is random
// and never starts with a digit.
func VarToggle(v any) string {
	id := "debug-toggle-" + strconv.FormatUint(rand.Uint64()>>1, 10)
	return Tpl.Must("debug_var_toggle.tmpl", map[string]string{"ID": id, "Var": Var(v)})
}
