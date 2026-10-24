// Package logview is the library behind the log viewers (/logs, /logsTail, /logsDownload): the file
// authorization policy, the tail reader, the ANSI to HTML converter and the human readable sizes.
//
// A file is readable only when,
// once canonicalized (symbolic links resolved), it lies under one of the directories that hold the logs of
// its type, and it is a regular file; see Policy.
package logview
