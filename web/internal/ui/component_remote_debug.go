package ui

// Remote debug modal.
const rdWebsocatVersion = "v1.14.1"

const rdInstallCommand = "mkdir -p ~/.local/bin\n" +
	"curl -sSL -o ~/.local/bin/websocat https://github.com/vi/websocat/releases/download/" + rdWebsocatVersion + "/websocat.x86_64-unknown-linux-musl\n" +
	"chmod +x ~/.local/bin/websocat"

const rdInstallWindows = "Invoke-WebRequest https://github.com/vi/websocat/releases/download/" + rdWebsocatVersion + "/websocat.x86_64-pc-windows-gnu.exe -OutFile websocat.exe"

// RemoteDebugModal renders the modal opened from the debug badge of an instance.
func RemoteDebugModal() string {
	return tpl.Must("remote_debug.tmpl", struct{ Install, WinInstall, Version string }{rdInstallCommand, rdInstallWindows, rdWebsocatVersion})
}

func init() { RemoteDebugModalHTML = RemoteDebugModal }
