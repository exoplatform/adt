package logview

import (
	"io"
	"os"
)

// MaxChunk caps what one poll returns (2 MiB), to bound the memory and the size of the response.
const MaxChunk = 2097152

// Tail is the result of ReadTail.
type Tail struct {
	Size      int64  // current size of the file: the offset to poll from next
	Data      []byte // new bytes (raw, not escaped)
	Truncated bool   // the file shrank or rotated since the offset was taken
	Skipped   int64  // bytes dropped because the delta exceeded MaxChunk
}

// ReadTail returns the part of the file appended after offset, for streaming a growing log.
func ReadTail(f *os.File, offset int64) (Tail, error) {
	fi, err := f.Stat()
	if err != nil {
		return Tail{}, err
	}
	t := Tail{Size: fi.Size()}
	if offset < 0 {
		offset = 0
	}
	if offset > t.Size { // rotated or truncated: restart from scratch
		offset = 0
		t.Truncated = true
	}
	if delta := t.Size - offset; delta > MaxChunk {
		t.Skipped = delta - MaxChunk
		offset = t.Size - MaxChunk
	}
	if t.Size > offset {
		buf := make([]byte, t.Size-offset)
		n, err := f.ReadAt(buf, offset)
		if err != nil && err != io.EOF && n == 0 {
			return t, err
		}
		t.Data = buf[:n]
	}
	return t, nil
}
