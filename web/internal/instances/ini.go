package instances

// Parser for the INI dialect of the descriptors of conf/adt/*, which the shell scripts write
// as KEY="value" / KEY=value lines:
// true|on|yes -> "1", false|off|no|none|null -> "", numbers stay strings, "..." is unescaped
// (\" \\ \$), '...' is raw, ;-comments, key[]=/key[name]= arrays, [sections] are ignored,
// unquoted | & ^ ~ ! ( ) evaluate as integer expressions, ${NAME} is a variable reference.
//
// Constants (KEY=E_ALL) are not expanded, and ${NAME} always
// expands to "" instead of reading the environment of the server process (an environment leak into a
// document that is served to other servers).

import (
	"errors"
	"strconv"
	"strings"
)

// ErrINISyntax is returned for a syntax error.
var ErrINISyntax = errors.New("ini: syntax error")

type iniArray struct {
	keys []string
	m    map[string]any
	next int
}

func (a *iniArray) set(key string, v any) {
	if _, ok := a.m[key]; !ok {
		a.keys = append(a.keys, key)
		if n, err := strconv.Atoi(key); err == nil && n >= a.next {
			a.next = n + 1
		}
	}
	a.m[key] = v
}

func (a *iniArray) push(v any) {
	a.set(strconv.Itoa(a.next), v)
}

// plain converts to the JSON-like value: a list when keys are 0..n-1.
func (a *iniArray) plain() any {
	list := true
	for i, k := range a.keys {
		if k != strconv.Itoa(i) {
			list = false
			break
		}
	}
	if list {
		out := make([]any, 0, len(a.keys))
		for _, k := range a.keys {
			out = append(out, a.m[k])
		}
		return out
	}
	out := make(map[string]any, len(a.keys))
	for _, k := range a.keys {
		out[k] = a.m[k]
	}
	return out
}

type iniTokKind int

const (
	tkEOL iniTokKind = iota // end of line (also: comment, '=' that ends a value)
	tkEOF
	tkAbort // stop
	tkStr   // constant, number, raw or plain string, whitespace
	tkWS
	tkQuote // '"' start or end handled inside scanDQ
	tkVar
	tkOp
	tkTrue
	tkFalse
	tkNull
	tkEq
	tkErr // unrecoverable scanner state (e.g. "${" without a variable name)
)

type iniTok struct {
	kind iniTokKind
	text string
}

type iniScanner struct {
	s   string
	pos int
}

func isTabSpace(c byte) bool { return c == ' ' || c == '\t' }

func (sc *iniScanner) skipTabSpace(p int) int {
	for p < len(sc.s) && isTabSpace(sc.s[p]) {
		p++
	}
	return p
}

// newlineAt returns the length of the newline at p (\r\n, \r or \n) or 0.
func (sc *iniScanner) newlineAt(p int) int {
	if p >= len(sc.s) {
		return 0
	}
	if sc.s[p] == '\r' {
		if p+1 < len(sc.s) && sc.s[p+1] == '\n' {
			return 2
		}
		return 1
	}
	if sc.s[p] == '\n' {
		return 1
	}
	return 0
}

// commentEnd returns the position after a ;-comment starting at p (which holds ';'), including its newline.
func (sc *iniScanner) commentEnd(p int) int {
	for p < len(sc.s) && sc.s[p] != '\r' && sc.s[p] != '\n' {
		p++
	}
	return p + sc.newlineAt(p)
}

func isLabelChar(c byte) bool {
	switch c {
	case '=', '\n', '\r', '\t', ';', '&', '|', '^', '$', '~', '(', ')', '{', '}', '!', '"', '[', ']', 0:
		return false
	}
	return true
}

func isValueChar(c byte) bool {
	switch c {
	case '$', '=', ' ', '\t', '\n', '\r', ';', '&', '|', '^', '~', '(', ')', '!', '"', '\'', 0:
		return false
	}
	return true
}

var iniKeywords = []struct {
	word string
	kind iniTokKind
}{
	{"true", tkTrue}, {"on", tkTrue}, {"yes", tkTrue},
	{"false", tkFalse}, {"off", tkFalse}, {"no", tkFalse}, {"none", tkFalse},
	{"null", tkNull},
}

// keyword returns the longest keyword matching (case-insensitively) at p, with its trailing blanks.
func (sc *iniScanner) keyword(p int) (iniTokKind, int) {
	best, bestKind := 0, tkEOL
	for _, k := range iniKeywords {
		if p+len(k.word) <= len(sc.s) && strings.EqualFold(sc.s[p:p+len(k.word)], k.word) {
			n := sc.skipTabSpace(p+len(k.word)) - p
			if n > best {
				best, bestKind = n, k.kind
			}
		}
	}
	return bestKind, best
}

// valueRun returns the length of the maximal VALUE_CHARS+ run at p.
func (sc *iniScanner) valueRun(p int) int {
	i := p
	for i < len(sc.s) {
		c := sc.s[i]
		if c == '$' {
			if i+1 >= len(sc.s) || sc.s[i+1] == '{' || sc.s[i+1] == 0 {
				break
			}
			if sc.s[i+1] == '\\' && i+2 < len(sc.s) {
				i += 3
			} else {
				i += 2
			}
			continue
		}
		if !isValueChar(c) {
			break
		}
		i++
	}
	return i - p
}

// valueToken scans one token in the ST_VALUE state.
func (sc *iniScanner) valueToken() iniTok {
	p := sc.pos
	if p >= len(sc.s) {
		return iniTok{kind: tkEOF}
	}
	q := sc.skipTabSpace(p)
	if q < len(sc.s) {
		if n := sc.newlineAt(q); n > 0 {
			sc.pos = q + n
			return iniTok{kind: tkEOL}
		}
		if sc.s[q] == ';' {
			end := sc.commentEnd(q)
			sc.pos = end
			if end >= len(sc.s) && !(end > 0 && (sc.s[end-1] == '\n' || sc.s[end-1] == '\r')) {
				// a comment ending the file without a newline is not an END_OF_LINE for the parser
				return iniTok{kind: tkAbort}
			}
			return iniTok{kind: tkEOL}
		}
		if sc.s[q] == '"' {
			sc.pos = q + 1
			return iniTok{kind: tkQuote}
		}
	} else if q > p {
		// trailing blanks at the very end of the file stay part of the value
		sc.pos = q
		return iniTok{kind: tkWS, text: sc.s[p:q]}
	}
	if q > p {
		sc.pos = q
		return iniTok{kind: tkWS, text: sc.s[p:q]}
	}
	c := sc.s[p]
	switch c {
	case '\'':
		if end := strings.IndexByte(sc.s[p+1:], '\''); end > 0 {
			sc.pos = p + 1 + end + 1
			return iniTok{kind: tkStr, text: sc.s[p+1 : p+1+end]}
		}
		if p+1 < len(sc.s) && sc.s[p+1] == '\'' {
			// an empty '' is not a raw string: the value ends here and scanning resumes from the second quote
			sc.pos = p + 1
			return iniTok{kind: tkEOL}
		}
		return iniTok{kind: tkAbort}
	case '=':
		return iniTok{kind: tkEq}
	case '&', '|', '^', '~', '(', ')', '!':
		sc.pos = sc.skipTabSpace(p + 1)
		return iniTok{kind: tkOp, text: string(c)}
	case '$':
		if p+1 == len(sc.s) { // a "$" ending the file reads as the end of input
			sc.pos = len(sc.s)
			return iniTok{kind: tkEOF}
		}
		if p+1 < len(sc.s) && sc.s[p+1] == '{' {
			t := sc.varRef(p + 2)
			if t.kind == tkAbort {
				t.kind = tkErr
			}
			return t
		}
	}
	kind, klen := sc.keyword(p)
	vlen := sc.valueRun(p)
	if klen > 0 && klen >= vlen {
		sc.pos = p + klen
		return iniTok{kind: kind}
	}
	if vlen > 0 {
		sc.pos = p + vlen
		return iniTok{kind: tkStr, text: sc.s[p : p+vlen]}
	}
	return iniTok{kind: tkAbort}
}

// varRef scans NAME} after "${" (ST_VARNAME).
func (sc *iniScanner) varRef(p int) iniTok {
	i := p
	for i < len(sc.s) && isLabelChar(sc.s[i]) {
		i++
	}
	if i == p || i >= len(sc.s) || sc.s[i] != '}' {
		return iniTok{kind: tkAbort}
	}
	sc.pos = i + 1
	return iniTok{kind: tkVar, text: sc.s[p:i]}
}

// scanDQ scans the inside of a double-quoted string (after the opening quote) and the closing quote;
// it returns the unescaped text, or ok=false when the string is not terminated.
func (sc *iniScanner) scanDQ() (string, bool) {
	var b strings.Builder
	for {
		p := sc.pos
		if p >= len(sc.s) {
			return "", false
		}
		if sc.s[p] == '"' {
			sc.pos = sc.skipTabSpace(p + 1)
			return b.String(), true
		}
		if sc.s[p] == '$' && p+1 < len(sc.s) && sc.s[p+1] == '{' {
			t := sc.varRef(p + 2)
			if t.kind != tkVar {
				return "", false
			}
			b.WriteString(expandVar(t.text))
			continue
		}
		i := p + 1
		n := len(sc.s)
	scan:
		for i < n {
			c := sc.s[i]
			i++
			switch c {
			case '"':
				if i < n && sc.s[i-2] == '\\' && sc.s[i] != '\r' && sc.s[i] != '\n' {
					continue
				}
				i--
				break scan
			case '$':
				if i < n && sc.s[i] == '{' {
					i--
					break scan
				}
			case '\\':
				if i < n && sc.s[i] != '"' {
					i++
				}
			}
		}
		b.WriteString(unescapeDQ(sc.s[p:i]))
		sc.pos = i
	}
}

// unescapeDQ is zend_ini_escape_string for quote_type '"': \" \\ \$ lose their backslash, other
// escapes are kept as is.
func unescapeDQ(s string) string {
	if !strings.Contains(s, `\`) {
		return s
	}
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] != '\\' {
			b.WriteByte(s[i])
			continue
		}
		i++
		if i >= len(s) {
			b.WriteByte('\\')
			break
		}
		switch s[i] {
		case '"', '\\', '$':
			b.WriteByte(s[i])
		default:
			b.WriteByte('\\')
			b.WriteByte(s[i])
		}
	}
	return b.String()
}

// expandVar is the value of ${name}; the process
// environment is deliberately not read here (see the package comment).
func expandVar(string) string { return "" }

// iniValue evaluates string_or_value after '=' (the scanner is in ST_VALUE). It returns the value and
// whether the scanner hit its abort token (parsing stops silently there).
func (sc *iniScanner) iniValue() (val string, abort bool, err error) {
	first := sc.valueToken()
	switch first.kind {
	case tkEOL:
		return "", false, nil
	case tkEOF:
		return "", false, nil
	case tkAbort, tkErr:
		return "", false, ErrINISyntax
	case tkTrue, tkFalse, tkNull:
		v := ""
		if first.kind == tkTrue {
			v = "1"
		}
		err = sc.expectEnd(&abort)
		return v, abort, err
	}
	p := &exprParser{sc: sc, tok: first}
	v, err := p.expr(0)
	if err != nil {
		return "", false, err
	}
	switch p.tok.kind {
	case tkEOL, tkEOF:
	case tkAbort:
		abort = true
	case tkEq:
		// '=' ends the value, then fails as the start of a statement
		return "", false, ErrINISyntax
	default:
		return "", false, ErrINISyntax
	}
	return v, abort, nil
}

func (sc *iniScanner) expectEnd(abort *bool) error {
	t := sc.valueToken()
	switch t.kind {
	case tkEOL, tkEOF:
		return nil
	case tkAbort:
		*abort = true
		return nil
	}
	return ErrINISyntax
}

// exprParser implements the expr grammar: '|' '&' '^' are left-associative at one level, '~' '!' bind tighter.
type exprParser struct {
	sc  *iniScanner
	tok iniTok
}

func (p *exprParser) next() { p.tok = p.sc.valueToken() }

func (p *exprParser) expr(depth int) (string, error) {
	if depth > 200 {
		return "", ErrINISyntax
	}
	left, err := p.unary(depth)
	if err != nil {
		return "", err
	}
	for p.tok.kind == tkOp && (p.tok.text == "|" || p.tok.text == "&" || p.tok.text == "^") {
		op := p.tok.text
		p.next()
		right, err := p.unary(depth)
		if err != nil {
			return "", err
		}
		a, b := iniAtoi(left), iniAtoi(right)
		switch op {
		case "|":
			left = strconv.FormatInt(a|b, 10)
		case "&":
			left = strconv.FormatInt(a&b, 10)
		default:
			left = strconv.FormatInt(a^b, 10)
		}
	}
	return left, nil
}

func (p *exprParser) unary(depth int) (string, error) {
	switch p.tok.kind {
	case tkOp:
		switch p.tok.text {
		case "~", "!":
			op := p.tok.text
			p.next()
			v, err := p.unary(depth + 1)
			if err != nil {
				return "", err
			}
			n := iniAtoi(v)
			if op == "~" {
				return strconv.FormatInt(^n, 10), nil
			}
			if n == 0 {
				return "1", nil
			}
			return "0", nil
		case "(":
			p.next()
			v, err := p.expr(depth + 1)
			if err != nil {
				return "", err
			}
			if p.tok.kind != tkOp || p.tok.text != ")" {
				return "", ErrINISyntax
			}
			p.next()
			return v, nil
		}
		return "", ErrINISyntax
	case tkStr, tkWS, tkVar, tkQuote:
		return p.stringList()
	}
	return "", ErrINISyntax
}

// stringList is var_string_list: adjacent strings, whitespace, "quoted" parts and ${refs} concatenate.
func (p *exprParser) stringList() (string, error) {
	var b strings.Builder
	for {
		switch p.tok.kind {
		case tkStr, tkWS:
			b.WriteString(p.tok.text)
		case tkVar:
			b.WriteString(expandVar(p.tok.text))
		case tkQuote:
			s, ok := p.sc.scanDQ()
			if !ok {
				return "", ErrINISyntax
			}
			b.WriteString(s)
		default:
			return b.String(), nil
		}
		p.next()
	}
}

// iniAtoi is the integer that expression operators make of a string (leading blanks, sign, decimal digits).
func iniAtoi(s string) int64 {
	s = strings.TrimLeft(s, " \t\n\r\v\f")
	i := 0
	if i < len(s) && (s[i] == '+' || s[i] == '-') {
		i++
	}
	j := i
	for j < len(s) && s[j] >= '0' && s[j] <= '9' {
		j++
	}
	n, _ := strconv.ParseInt(s[:j], 10, 64)
	return n
}

// ParseINI parses a descriptor. It returns ErrINISyntax on a syntax error.
func ParseINI(content string) (map[string]any, error) {
	sc := &iniScanner{s: content}
	res := &iniArray{m: map[string]any{}}
loop:
	for {
		p := sc.pos
		if p >= len(sc.s) {
			break
		}
		q := sc.skipTabSpace(p)
		// blank line / comment
		if q < len(sc.s) {
			if n := sc.newlineAt(q); n > 0 {
				sc.pos = q + n
				continue
			}
			if sc.s[q] == ';' {
				sc.pos = sc.commentEnd(q)
				continue
			}
		}
		if q >= len(sc.s) {
			break
		}
		c := sc.s[q]
		if c == '[' && q == p {
			// section header: ignored (process_sections=false)
			end := strings.IndexByte(sc.s[q:], ']')
			if end < 0 {
				return nil, ErrINISyntax
			}
			if strings.ContainsAny(sc.s[q+1:q+end], "\r\n;\"'$\\") {
				return nil, ErrINISyntax // not a valid section name for the scanner
			}
			e := q + end + 1
			e = sc.skipTabSpace(e)
			e += sc.newlineAt(e)
			sc.pos = e
			continue
		}
		// longest of: keyword (error), LABEL / LABEL[ , '='
		_, klen := sc.keyword(p)
		ll := 0
		for p+ll < len(sc.s) && isLabelChar(sc.s[p+ll]) {
			ll++
		}
		if klen > 0 && klen >= ll {
			return nil, ErrINISyntax // BOOL_*/NULL where a statement must start
		}
		if ll == 0 || (q > p && ll < q-p) {
			if c == '=' || (q < len(sc.s) && sc.s[q] == '=') {
				return nil, ErrINISyntax
			}
			if q > p {
				sc.pos = q
				continue
			}
			return nil, ErrINISyntax // characters no rule matches are a syntax error
		}
		label := strings.Trim(sc.s[p:p+ll], " ")
		if label == "" { // only blanks: eaten as whitespace, unless '=' or '[' follows (both are then errors)
			if r := sc.skipTabSpace(p + ll); r < len(sc.s) && (sc.s[r] == '=' || sc.s[r] == '[') {
				return nil, ErrINISyntax
			}
			sc.pos = p + ll
			continue
		}
		sc.pos = p + ll
		offset, hasOffset := "", false
		if sc.pos < len(sc.s) && sc.s[sc.pos] == '[' {
			hasOffset = true
			end := strings.IndexByte(sc.s[sc.pos:], ']')
			if end < 0 {
				return nil, ErrINISyntax
			}
			offset = strings.Trim(sc.s[sc.pos+1:sc.pos+end], " \t")
			offset = strings.Trim(offset, `"'`)
			sc.pos += end + 1
		}
		// after the label: blanks then '=' ?
		r := sc.skipTabSpace(sc.pos)
		if r < len(sc.s) && sc.s[r] == '=' {
			sc.pos = sc.skipTabSpace(r + 1)
			val, abort, err := sc.iniValue()
			if err != nil {
				return nil, err
			}
			if hasOffset {
				arr, ok := res.m[label].(*iniArray)
				if !ok {
					arr = &iniArray{m: map[string]any{}}
					res.set(label, arr)
				}
				if offset == "" {
					arr.push(val)
				} else {
					arr.set(offset, val)
				}
			} else {
				res.set(label, val)
			}
			if abort {
				break loop
			}
			continue
		}
		if hasOffset {
			return nil, ErrINISyntax
		}
		// a bare label is a valid statement without value: ignored
	}
	m := make(map[string]any, len(res.keys))
	for _, k := range res.keys {
		if a, ok := res.m[k].(*iniArray); ok {
			m[k] = a.plain()
		} else {
			m[k] = res.m[k]
		}
	}
	return m, nil
}
