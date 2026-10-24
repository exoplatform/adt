package instances

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
)

// MarshalJSON renders the branches as an object whose
// keys keep their order (that order drives the page rendering on the servers that consume it), or [] when
// there is no branch. Strings are not HTML-escaped.
func (b *Branches) MarshalJSON() ([]byte, error) {
	if b == nil || len(b.order) == 0 {
		return []byte("[]"), nil
	}
	var buf bytes.Buffer
	buf.WriteByte('{')
	for n, k := range b.order {
		if n > 0 {
			buf.WriteByte(',')
		}
		if err := encodeNoEscape(&buf, k); err != nil {
			return nil, err
		}
		buf.WriteByte(':')
		list := b.m[k]
		if list == nil {
			list = []Instance{}
		}
		if err := encodeNoEscape(&buf, list); err != nil {
			return nil, err
		}
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

func encodeNoEscape(buf *bytes.Buffer, v any) error {
	enc := json.NewEncoder(buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return err
	}
	buf.Truncate(buf.Len() - 1) // the newline Encode adds
	return nil
}

// ErrNotBranches is returned for a JSON document that is neither an object nor a list.
var ErrNotBranches = errors.New("instances: JSON is not a branch => instances map")

// UnmarshalJSON reads an object (or a list) of
// branch => list of instance objects, keeping the order of the keys. A duplicated key keeps its first
// position and its last value.
func (b *Branches) UnmarshalJSON(data []byte) error {
	nb := NewBranches()
	dec := json.NewDecoder(bytes.NewReader(data))
	tok, err := dec.Token()
	if err != nil {
		return err
	}
	switch tok {
	case json.Delim('{'):
		for dec.More() {
			kt, err := dec.Token()
			if err != nil {
				return err
			}
			key, _ := kt.(string)
			var raw json.RawMessage
			if err := dec.Decode(&raw); err != nil {
				return err
			}
			nb.set(key, decodeInstanceList(raw))
		}
	case json.Delim('['):
		for i := 0; dec.More(); i++ {
			var raw json.RawMessage
			if err := dec.Decode(&raw); err != nil {
				return err
			}
			nb.set(strconv.Itoa(i), decodeInstanceList(raw))
		}
	default:
		return fmt.Errorf("%w (%v)", ErrNotBranches, tok)
	}
	*b = *nb
	return nil
}

// decodeInstanceList decodes the instances of one branch: a list of objects (values of an object are taken
// in order). Anything else is an empty list (mergeInstances skips falsy entries).
func decodeInstanceList(raw json.RawMessage) []Instance {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 {
		return nil
	}
	var out []Instance
	switch raw[0] {
	case '[':
		var items []json.RawMessage
		if json.Unmarshal(raw, &items) != nil {
			return nil
		}
		for _, it := range items {
			var i Instance
			if json.Unmarshal(it, &i) == nil && i != nil {
				out = append(out, i)
			}
		}
	case '{':
		dec := json.NewDecoder(bytes.NewReader(raw))
		_, _ = dec.Token()
		for dec.More() {
			_, _ = dec.Token()
			var i Instance
			if dec.Decode(&i) == nil && i != nil {
				out = append(out, i)
			}
		}
	}
	return out
}
