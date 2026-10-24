package gitx

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// Package knobs.
var (
	// GitExecutable is the git binary (PATH is used when absent).
	GitExecutable = "/usr/bin/git"
	// Timeout bounds one git invocation.
	Timeout = 60 * time.Second
	// MaxOutput bounds the stdout read from one git invocation.
	MaxOutput = 64 << 20
)

// ErrOutputTooLarge is returned when git printed more than MaxOutput bytes.
var ErrOutputTooLarge = errors.New("gitx: git output too large")

// GitError is the error of a failed git invocation.
type GitError struct {
	Args     []string
	ExitCode int
	Stderr   string
}

func (e *GitError) Error() string {
	return fmt.Sprintf("git %s failed with code %d: %s", strings.Join(e.Args, " "), e.ExitCode, strings.TrimSpace(e.Stderr))
}

type limitBuffer struct {
	buf      bytes.Buffer
	max      int
	overflow bool
}

func (l *limitBuffer) Write(p []byte) (int, error) {
	if l.buf.Len()+len(p) > l.max {
		l.overflow = true
		return 0, ErrOutputTooLarge
	}
	return l.buf.Write(p)
}

func gitBinary() string {
	if _, err := os.Stat(GitExecutable); err == nil {
		return GitExecutable
	}
	if p, err := exec.LookPath("git"); err == nil {
		return p
	}
	return GitExecutable
}

// phpTrim trims spaces, tabs, newlines, carriage returns, NUL and vertical tabs.
func phpTrim(s string) string { return strings.Trim(s, " \t\n\r\x00\x0b") }

// run executes "git args..." in dir. The output is trimmed. Exit
// status 1 of "git status" is not an error.
func run(dir string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), Timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, gitBinary(), args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0", "GIT_OPTIONAL_LOCKS=0", "GIT_ASKPASS=true")
	cmd.WaitDelay = 2 * time.Second
	out := &limitBuffer{max: MaxOutput}
	errBuf := &limitBuffer{max: 64 << 10}
	cmd.Stdout, cmd.Stderr = out, errBuf
	err := cmd.Run()
	if out.overflow {
		return "", ErrOutputTooLarge
	}
	if err != nil {
		if ctx.Err() != nil {
			return "", fmt.Errorf("git %s: %w", strings.Join(args, " "), ctx.Err())
		}
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			if ee.ExitCode() == 1 && len(args) > 0 && args[0] == "status" {
				return phpTrim(out.buf.String()), nil
			}
			return "", &GitError{Args: args, ExitCode: ee.ExitCode(), Stderr: errBuf.buf.String()}
		}
		return "", err
	}
	return phpTrim(out.buf.String()), nil
}
