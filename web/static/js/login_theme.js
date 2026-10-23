// Same storage and values as the dashboard: theme = "accent:scheme", customColor = "#rrggbb".
// Applied before first paint; without a stored choice the system preference decides.
(function () {
    var root = document.documentElement, raw = '', custom = '';
    try { raw = localStorage.getItem('theme') || ''; custom = localStorage.getItem('customColor') || ''; } catch (e) {}
    var parts = raw.indexOf(':') > 0 ? raw.split(':') : ['', raw];
    var accent = parts[0], scheme = parts[1];
    // Accents removed from the dashboard map to the closest remaining one
    accent = { twilight: 'default', midnight: 'default', lavender: 'default', gold: 'default', sunset: 'rose', crimson: 'rose' }[accent] || accent;
    if (['ocean', 'forest', 'rose', 'slate', 'custom'].indexOf(accent) < 0) accent = 'default';
    if (accent === 'custom') {
        if (/^#[0-9a-f]{6}$/i.test(custom)) {
            // Only the raw colour: the stylesheet below derives the readable variants from it
            root.style.setProperty('--accent-src', custom);
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
