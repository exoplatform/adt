package app

import (
	"io/fs"
	"os"
)

// osFS serves a directory from disk (ADT_STATIC_DIR, development only).
func osFS(dir string) fs.FS { return os.DirFS(dir) }
