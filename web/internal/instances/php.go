package instances

// Loose-typing semantics the descriptors rely on (loose comparison, empty values, numeric strings).

import (
	"fmt"
	"math"
	"regexp"
	"strconv"
	"strings"
)

var numericRe = regexp.MustCompile(`^[ \t\n\r\v\f]*[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][+-]?[0-9]+)?[ \t\n\r\v\f]*$`)

// isNumericStr reports whether s is a numeric string (leading and trailing blanks allowed).
func isNumericStr(s string) bool { return numericRe.MatchString(s) }

func numVal(s string) float64 {
	f, _ := strconv.ParseFloat(strings.TrimSpace(s), 64)
	return f
}

// looseEqStrings compares two strings loosely: numeric strings compare as numbers.
func looseEqStrings(a, b string) bool {
	if a == b {
		return true
	}
	if isNumericStr(a) && isNumericStr(b) {
		return numVal(a) == numVal(b)
	}
	return false
}

// looseEqAny compares a label to a decoded JSON value loosely (numeric strings compare as numbers).
func looseEqAny(label string, v any) bool {
	switch x := v.(type) {
	case nil:
		return label == ""
	case string:
		return looseEqStrings(label, x)
	case bool:
		return (label != "" && label != "0") == x
	case float64:
		if isNumericStr(label) {
			return numVal(label) == x
		}
		return label == formatFloat(x)
	case int:
		return looseEqAny(label, float64(x))
	}
	return false
}

func formatFloat(f float64) string {
	if f == math.Trunc(f) && math.Abs(f) < 1e15 {
		return strconv.FormatInt(int64(f), 10)
	}
	return strconv.FormatFloat(f, 'G', 14, 64)
}

// phpEmptyStr reports whether s is empty: "" or "0".
func phpEmptyStr(s string) bool { return s == "" || s == "0" }

// descStr reads a descriptor value as a string ("" when missing or not a scalar string).
func descStr(d map[string]any, key string) string {
	switch v := d[key].(type) {
	case string:
		return v
	case nil:
		return ""
	default:
		return fmt.Sprint(v)
	}
}
