package logview

import (
	"strconv"
	"strings"
)

var fgColors = map[int]string{
	30: "#5c5c5c", 31: "#e74c3c", 32: "#2ecc71", 33: "#d4ac0d",
	34: "#5dade2", 35: "#bb6bd9", 36: "#48c9b0", 37: "#d5d8dc",
	90: "#888888", 91: "#ff6b6b", 92: "#6bdc9c", 93: "#f7dc6f",
	94: "#85c1e9", 95: "#d2b4de", 96: "#76d7c4", 97: "#f4f6f7",
}

var bgColors = map[int]string{
	40: "#000000", 41: "#e74c3c", 42: "#2ecc71", 43: "#d4ac0d",
	44: "#5dade2", 45: "#bb6bd9", 46: "#48c9b0", 47: "#d5d8dc",
	100: "#888888", 101: "#ff6b6b", 102: "#6bdc9c", 103: "#f7dc6f",
	104: "#85c1e9", 105: "#d2b4de", 106: "#76d7c4", 107: "#f4f6f7",
}

var noQuotes = strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;")

// EscapeNoQuotes escapes & < > only (quotes are text in element
// content). Invalid UTF-8 becomes U+FFFD.
func EscapeNoQuotes(s string) string { return noQuotes.Replace(strings.ToValidUTF8(s, "�")) }

// Render turns raw log text into the HTML of the log viewer: escape first, then convert the ANSI colors.
// It is the only entry point the pages use, so the order cannot be got wrong.
func Render(raw string) string { return AnsiToHTML(EscapeNoQuotes(raw)) }

// AnsiToHTML converts ANSI SGR sequences (ESC [ codes m) of an ALREADY HTML-escaped text
// into <span style="..."> markup. The ESC character and the digits survive escaping untouched. Only values
// from the fixed color tables reach the style attribute, whatever the input holds; other escape sequences
// are left as they are (text).
func AnsiToHTML(text string) string {
	var (
		out      strings.Builder
		last     int
		spanOpen bool
		fg, bg   string
		bold     bool
		matched  bool
	)
	for i := 0; i < len(text); {
		// \x1b\[([0-9;]*)m
		if text[i] != 0x1b || i+1 >= len(text) || text[i+1] != '[' {
			i++
			continue
		}
		j := i + 2
		for j < len(text) && (text[j] >= '0' && text[j] <= '9' || text[j] == ';') {
			j++
		}
		if j >= len(text) || text[j] != 'm' {
			i++
			continue
		}
		matched = true
		out.WriteString(text[last:i])
		last = j + 1
		raw := text[i+2 : j]
		i = j + 1

		codes := []int{0}
		if raw != "" {
			codes = codes[:0]
			for _, p := range strings.Split(raw, ";") {
				codes = append(codes, intval(p))
			}
		}
		for _, code := range codes {
			switch {
			case code == 0:
				fg, bg, bold = "", "", false
			case code == 1:
				bold = true
			case code == 22:
				bold = false
			case code == 39:
				fg = ""
			case code == 49:
				bg = ""
			default:
				if c, ok := fgColors[code]; ok {
					fg = c
				} else if c, ok := bgColors[code]; ok {
					bg = c
				}
			}
		}
		if spanOpen {
			out.WriteString("</span>")
			spanOpen = false
		}
		var style []string
		if fg != "" {
			style = append(style, "color:"+fg)
		}
		if bg != "" {
			style = append(style, "background-color:"+bg)
		}
		if bold {
			style = append(style, "font-weight:bold")
		}
		if len(style) > 0 {
			out.WriteString(`<span style="` + strings.Join(style, ";") + `">`)
			spanOpen = true
		}
	}
	if !matched {
		return text
	}
	out.WriteString(text[last:])
	if spanOpen {
		out.WriteString("</span>")
	}
	return out.String()
}

// intval is the integer value of a string made of digits: huge values saturate (they match no color).
func intval(s string) int {
	if s == "" {
		return 0
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return -1
	}
	return n
}
