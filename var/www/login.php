<?php
// Login page. Credentials are posted to /dologin, handled by Apache (mod_auth_form)
// which validates them against the LDAP backend and sets the session cookie.
// A failed attempt is redirected back here with the login form as the Referer.

/**
 * Extract the URL to return to after login from a raw query string ("next=<escaped path?query>").
 * Apache escapes the "?" but not the "&", so the whole raw string after "next=" is the target.
 * Only local paths are accepted (no open redirect, no login/logout loops).
 */
function followupTarget($rawQuery)
{
    if (!is_string($rawQuery) || strncmp($rawQuery, 'next=', 5) !== 0) {
        return null;
    }
    $t = rtrim(rawurldecode(substr($rawQuery, 5)), '?');
    if ($t === '' || $t[0] !== '/' || strlen($t) > 2048) {
        return null;
    }
    if (isset($t[1]) && ($t[1] === '/' || $t[1] === '\\')) {
        return null;
    }
    if (preg_match('/[\x00-\x1f\x7f\\\\]/', $t) || preg_match('#^/(login|dologin|logout)(\.php)?([/?\#]|$)#i', $t)) {
        return null;
    }
    return $t;
}

$referer = parse_url($_SERVER['HTTP_REFERER'] ?? '');
$refererOurs = !empty($referer['host']) && strcasecmp($referer['host'], preg_replace('/:\d+$/', '', $_SERVER['HTTP_HOST'] ?? '')) === 0;
$failed = ($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'GET' && $refererOurs
    && preg_match('#^/login(\.php)?$#', (string)($referer['path'] ?? ''));
// The target comes from the URL, or from the login form we were redirected back from after a failed attempt
$next = followupTarget($_SERVER['QUERY_STRING'] ?? '');
if ($next === null && $failed) {
    $next = followupTarget($referer['query'] ?? '');
}
header('X-Frame-Options: DENY');

// Already signed in: no need to show the form (Apache exposes the decrypted session as HTTP_SESSION)
// Keys are prefixed with the AuthName ("<realm>-user"); only the user name is looked at here.
parse_str($_SERVER['HTTP_SESSION'] ?? '', $session);
foreach ($session as $key => $value) {
    if (substr($key, -5) === '-user' && $value !== '') {
        header('Location: ' . ($next ?? '/'));
        exit;
    }
}
unset($session);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex">
    <meta name="color-scheme" content="dark light">
    <script>
        // Same storage and values as the dashboard: theme = "accent:scheme", customColor = "#rrggbb".
        // Applied before first paint; without a stored choice the system preference decides.
        (function () {
            var root = document.documentElement, raw = '', custom = '';
            try { raw = localStorage.getItem('theme') || ''; custom = localStorage.getItem('customColor') || ''; } catch (e) {}
            var parts = raw.indexOf(':') > 0 ? raw.split(':') : ['', raw];
            var accent = parts[0], scheme = parts[1];
            if (['ocean', 'forest', 'twilight', 'sunset', 'midnight', 'lavender', 'crimson', 'rose', 'gold', 'custom'].indexOf(accent) < 0) accent = 'default';
            if (accent === 'custom') {
                if (/^#[0-9a-f]{6}$/i.test(custom)) {
                    // Pick white or dark button text, whichever contrasts better with the chosen colour
                    var c = [1, 3, 5].map(function (i) {
                        var v = parseInt(custom.substr(i, 2), 16) / 255;
                        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
                    });
                    var l = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
                    root.style.setProperty('--accent', custom);
                    var white = 1.05 / (l + 0.05) >= (l + 0.05) / 0.0533;
                    root.style.setProperty('--on-accent', white ? '#fff' : '#0a0a14');
                    root.style.setProperty('--hover-tone', white ? '#000' : '#fff');
                } else {
                    accent = 'default';
                }
            }
            root.setAttribute('data-accent', accent);
            if (scheme !== 'light' && scheme !== 'dark') {
                scheme = window.matchMedia && matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
            }
            root.setAttribute('data-bs-theme', scheme);
        })();
    </script>
    <title>Sign in - eXo Acceptance</title>
    <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png">
    <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32x32.png">
    <link rel="icon" type="image/x-icon" href="/images/favicon.ico">
    <style>
        :root {
            --bg-base: #06060e; --card-base: #0c0c1a; --field-base: #1a1a32; --border: rgba(255,255,255,0.12);
            --text: #f0f0f8; --muted: #9898b8; --error: #ff8a8a; --error-bg: rgba(255,90,90,0.12);
            --shadow: rgba(0,0,0,0.35);
            /* Accent (default = dashboard violet); the data-accent rules below override it */
            --accent: #6c5ce7; --on-accent: #fff; --hover-tone: #000;
            --tone: #fff; --text-pct: 75%; --glow-pct: 28%;
        }
        :root[data-bs-theme=dark] { color-scheme: dark; }
        :root[data-bs-theme=light] { color-scheme: light; }
        :root[data-bs-theme=light] {
            --bg-base: #f2f2f8; --card-base: #ffffff; --field-base: #f6f6fb; --border: rgba(10,10,20,0.14);
            --text: #14142a; --muted: #5c5c78; --error: #b42318; --error-bg: rgba(180,35,24,0.08);
            --shadow: rgba(40,40,80,0.12);
            --tone: #000; --text-pct: 55%; --glow-pct: 18%;
        }
        :root[data-bs-theme=light][data-accent=default] { --accent: #5b4ae0; }
        /* Accent themes, same colours as the dashboard (style.css). Button text is chosen for WCAG contrast. */
        :root[data-accent=ocean]    { --accent: #0ea5e9; --on-accent: #0a0a14; --hover-tone: #fff; }
        :root[data-accent=forest]   { --accent: #10b981; --on-accent: #0a0a14; --hover-tone: #fff; }
        :root[data-accent=twilight] { --accent: #8b5cf6; --on-accent: #0a0a14; --hover-tone: #fff; }
        :root[data-accent=sunset]   { --accent: #f97316; --on-accent: #0a0a14; --hover-tone: #fff; }
        :root[data-accent=midnight] { --accent: #6366f1; --on-accent: #fff; --hover-tone: #000; }
        :root[data-accent=lavender] { --accent: #c084fc; --on-accent: #0a0a14; --hover-tone: #fff; }
        :root[data-accent=crimson]  { --accent: #ef4444; --on-accent: #0a0a14; --hover-tone: #fff; }
        :root[data-accent=rose]     { --accent: #ec4899; --on-accent: #0a0a14; --hover-tone: #fff; }
        :root[data-accent=gold]     { --accent: #eab308; --on-accent: #0a0a14; --hover-tone: #fff; }
        /* Everything derived from the accent, as on the dashboard (surfaces get a light tint) */
        :root {
            --bg: color-mix(in srgb, var(--accent) 3%, var(--bg-base));
            --card: color-mix(in srgb, var(--accent) 5%, var(--card-base));
            --field: color-mix(in srgb, var(--accent) 9%, var(--field-base));
            --glow: color-mix(in srgb, var(--accent) var(--glow-pct), transparent);
            --accent-hover: color-mix(in srgb, var(--accent) 88%, var(--hover-tone));
            --accent-text: color-mix(in srgb, var(--accent) var(--text-pct), var(--tone));
        }
        /* Without JavaScript the system preference decides */
        @media (prefers-color-scheme: light) {
            :root:not([data-bs-theme]) {
                --bg-base: #f2f2f8; --card-base: #ffffff; --field-base: #f6f6fb; --border: rgba(10,10,20,0.14);
                --text: #14142a; --muted: #5c5c78; --error: #b42318; --error-bg: rgba(180,35,24,0.08);
                --shadow: rgba(40,40,80,0.12); --accent: #5b4ae0;
                --tone: #000; --text-pct: 55%; --glow-pct: 18%;
            }
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 16px;
            background: radial-gradient(900px 500px at 50% -10%, var(--glow), transparent 70%), var(--bg);
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            color: var(--text); -webkit-font-smoothing: antialiased;
        }
        main {
            width: 100%; max-width: 400px; padding: 36px 32px 32px; border-radius: 20px;
            background: var(--card); border: 1px solid var(--border);
            box-shadow: 0 24px 60px var(--shadow);
        }
        .brand { display: flex; flex-direction: column; align-items: center; text-align: center; margin-bottom: 28px; }
        .brand img { width: 56px; height: 56px; margin-bottom: 14px; }
        h1 { font-size: 1.35rem; font-weight: 700; letter-spacing: -0.01em; }
        .sub { color: var(--muted); font-size: .9rem; margin-top: 4px; }
        label { display: block; font-size: .82rem; font-weight: 500; margin: 16px 0 6px; }
        input, button { font: inherit; }
        input[type=text], input[type=password] {
            width: 100%; padding: 11px 12px; border-radius: 10px; font-size: 1rem; color: var(--text);
            background: var(--field); border: 1px solid var(--border);
        }
        input::placeholder { color: var(--muted); opacity: .7; }
        input:focus-visible, button:focus-visible { outline: 2px solid var(--accent-text); outline-offset: 2px; }
        .pw { position: relative; }
        .pw input { padding-right: 44px; }
        .pw button {
            position: absolute; top: 0; right: 0; bottom: 0; width: 44px; border: 0; background: none;
            color: var(--muted); cursor: pointer; border-radius: 0 10px 10px 0; display: grid; place-items: center;
        }
        .pw button:hover { color: var(--text); }
        .pw svg { width: 20px; height: 20px; }
        .pw .off { display: none; }
        .pw button[aria-pressed=true] .on { display: none; }
        .pw button[aria-pressed=true] .off { display: block; }
        label.check { display: flex; align-items: center; gap: 8px; margin: 18px 0 0; color: var(--muted); font-weight: 400; cursor: pointer; }
        label.check input { width: 16px; height: 16px; accent-color: var(--accent); }
        .submit {
            width: 100%; margin-top: 22px; padding: 12px; border: 0; border-radius: 10px; cursor: pointer;
            font-size: 1rem; font-weight: 600; color: var(--on-accent); background: var(--accent); transition: background .15s;
        }
        .submit:hover { background: var(--accent-hover); }
        .submit[disabled] { opacity: .7; cursor: progress; }
        .restricted {
            display: inline-flex; align-items: center; gap: 6px; margin-top: 14px; padding: 5px 12px; border-radius: 999px;
            font-size: .78rem; font-weight: 500; color: var(--accent-text); background: color-mix(in srgb, var(--accent) 16%, transparent); border: 1px solid var(--border);
        }
        .restricted svg { width: 14px; height: 14px; flex: none; }
        .help { margin-top: 22px; text-align: center; font-size: .85rem; color: var(--muted); }
        .help a { color: var(--accent-text); text-decoration: none; font-weight: 500; }
        .help a:hover, .help a:focus-visible { text-decoration: underline; }
        .error {
            margin-bottom: 4px; padding: 10px 12px; border-radius: 10px; font-size: .88rem;
            color: var(--error); background: var(--error-bg);
        }
        .theme-toggle {
            position: fixed; top: 16px; right: 16px; width: 40px; height: 40px; border-radius: 10px; cursor: pointer;
            display: grid; place-items: center; color: var(--muted); background: var(--card); border: 1px solid var(--border);
        }
        .theme-toggle:hover { color: var(--text); }
        .theme-toggle svg { width: 20px; height: 20px; }
        .theme-toggle .sun { display: none; }
        :root[data-bs-theme=dark] .theme-toggle .sun { display: block; }
        :root[data-bs-theme=dark] .theme-toggle .moon { display: none; }
        @media (max-width: 420px) { main { padding: 28px 20px 24px; border-radius: 16px; } }
    </style>
</head>
<body>
<button type="button" class="theme-toggle" id="th" aria-label="Switch to light mode" title="Toggle dark / light mode">
    <svg class="sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
    <svg class="moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>
</button>
<main>
    <div class="brand">
        <img src="/images/logo.svg" alt="" width="56" height="56">
        <h1>eXo Acceptance</h1>
        <p class="sub">Sign in with your eXo account</p>
        <p class="restricted"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>Access restricted to eXo employees only</p>
    </div>
    <?php if ($failed) { ?>
        <p class="error" role="alert">Invalid credentials, or your account is not allowed to access this site.</p>
    <?php } ?>
    <form method="post" action="/dologin" id="f">
        <?php if ($next !== null) { ?><input type="hidden" name="httpd_location" value="<?= htmlspecialchars($next, ENT_QUOTES) ?>"><?php } ?>
        <label for="u">Username</label>
        <input id="u" name="httpd_username" type="text" autocomplete="username" autocapitalize="none" spellcheck="false" required autofocus>
        <label for="p">Password</label>
        <div class="pw">
            <input id="p" name="httpd_password" type="password" autocomplete="current-password" required>
            <button type="button" id="t" aria-label="Show password" aria-pressed="false">
                <svg class="on" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>
                <svg class="off" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M17.94 17.94A10.9 10.9 0 0 1 12 19c-7 0-11-7-11-7a19.8 19.8 0 0 1 5.06-5.94M9.9 4.24A10.9 10.9 0 0 1 12 5c7 0 11 7 11 7a19.8 19.8 0 0 1-3.17 4.19M1 1l22 22"/></svg>
            </button>
        </div>
        <label class="check"><input id="r" type="checkbox"> Remember me for 7 days</label>
        <button class="submit" type="submit">Sign in</button>
    </form>
<p class="help">Having trouble signing in? Contact <a href="mailto:support@exoplatform.com">support@exoplatform.com</a></p>
</main>
<script>
    var f = document.getElementById('f'), p = document.getElementById('p'), t = document.getElementById('t');
    // Remember me posts to the long-lived session handler; without JS the 8h one is used
    f.addEventListener('submit', function () {
        f.action = document.getElementById('r').checked ? '/dologin-remember' : '/dologin';
        f.querySelector('.submit').disabled = true;
    });
    // Back/forward cache can restore the page with the button still disabled
    window.addEventListener('pageshow', function () { f.querySelector('.submit').disabled = false; });
    // Light/dark toggle: persists in the dashboard's "theme" key, keeping its accent
    var th = document.getElementById('th'), root = document.documentElement;
    function syncLabel() { th.setAttribute('aria-label', root.getAttribute('data-bs-theme') === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'); }
    function storedScheme() { try { return localStorage.getItem('theme') || ''; } catch (e) { return ''; } }
    th.addEventListener('click', function () {
        var next = root.getAttribute('data-bs-theme') === 'dark' ? 'light' : 'dark';
        var raw = storedScheme(), accent = raw.indexOf(':') > 0 ? raw.split(':')[0] : 'default';
        root.setAttribute('data-bs-theme', next);
        try { localStorage.setItem('theme', accent + ':' + next); } catch (e) {}
        syncLabel();
    });
    // Follow the system while the user hasn't picked one
    if (window.matchMedia) {
        matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
            var raw = storedScheme();
            if (raw === '' || raw === 'light' || raw === 'dark') { root.setAttribute('data-bs-theme', e.matches ? 'dark' : 'light'); syncLabel(); }
        });
    }
    syncLabel();
    t.addEventListener('click', function () {
        var show = p.type === 'password';
        p.type = show ? 'text' : 'password';
        t.setAttribute('aria-pressed', show);
        t.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
    });
</script>
</body>
</html>
