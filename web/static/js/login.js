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
