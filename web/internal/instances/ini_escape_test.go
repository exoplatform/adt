package instances

import "testing"

// The descriptors are read by bash (source) and by adt-web, from the same file, and the template writes the values raw: callers
// escape what they need for bash (DEPLOYMENT_OPTS holds \"0 0/60 * * * *\" for the quotes of a cron expression, \$ in a regular
// expression, ... as documented in adt.sh). adt-web must read the same characters bash does: \" \\ and \$ lose their backslash.
func TestParseINIReadsTheEscapesOfADescriptor(t *testing.T) {
	for _, tc := range []struct{ file, want string }{
		{`A="plain"`, "plain"},
		{`A="say \"hi\""`, `say "hi"`},
		{`A="back\\slash"`, `back\slash`},
		{`A="cost \$5 and \$HOME"`, `cost $5 and $HOME`},
		{`A="x\"; touch PWNED; \""`, `x"; touch PWNED; "`},
		{`A="a\\\"b\$c"`, `a\"b$c`},
		{`A="trailing backslash \\"`, `trailing backslash \`},
		{`A="https://h/p?a=1&b=2"`, `https://h/p?a=1&b=2`},
		{`A="-Dexo.job.expression=\"0 0/60 * * * *\" -Dx=1"`, `-Dexo.job.expression="0 0/60 * * * *" -Dx=1`},
		{`A="-Dr=\"^[a-z0-9@.]*$\" -Dz=2"`, `-Dr="^[a-z0-9@.]*$" -Dz=2`},
		{`A="${NAME}"`, ``}, // a variable reference stays an empty expansion: the server environment is never read
	} {
		got, err := ParseINI(tc.file + "\n")
		if err != nil {
			t.Errorf("%s: %v", tc.file, err)
			continue
		}
		if v, _ := got["A"].(string); v != tc.want {
			t.Errorf("%s: read %q, want %q", tc.file, v, tc.want)
		}
	}
}
