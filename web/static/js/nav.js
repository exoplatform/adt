(function () {
  var menu = document.getElementById('sessionMenu'), toggle = document.getElementById('sessionMenuToggle'),
      panel = document.getElementById('sessionMenuPanel'), out = document.getElementById('sessionRemaining');
  if (!menu || !toggle || !panel) return;
  var expiry = parseInt(menu.getAttribute('data-expiry'), 10) * 1000;
  function label(ms) {
    var left = Math.max(0, Math.floor(ms / 1000)), d = Math.floor(left / 86400),
        h = Math.floor(left % 86400 / 3600), m = Math.floor(left % 3600 / 60);
    return d > 0 ? d + 'd ' + h + 'h' : h + 'h ' + m + 'm';
  }
  function refresh() {
    var left = expiry - Date.now();
    out.textContent = left <= 0 ? 'expired' : label(left);
    // Amber dot on the icon when less than 30 minutes remain
    menu.classList.toggle('session-menu--soon', left < 30 * 60 * 1000);
  }
  function setOpen(open) {
    panel.hidden = !open;
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    if (open) refresh();
  }
  toggle.addEventListener('click', function (e) { e.preventDefault(); setOpen(panel.hidden); });
  document.addEventListener('click', function (e) { if (!menu.contains(e.target)) setOpen(false); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && !panel.hidden) { setOpen(false); toggle.focus(); } });
  refresh();
  setInterval(refresh, 30000);
})();

(function () {
  var els = document.querySelectorAll('[data-session-expiry]');
  function tick() {
    els.forEach(function (el) {
      var left = Math.max(0, Math.floor(parseInt(el.getAttribute('data-session-expiry'), 10) - Date.now() / 1000)),
          d = Math.floor(left / 86400), h = Math.floor(left % 86400 / 3600), m = Math.floor(left % 3600 / 60);
      var label = left === 0 ? 'expired' : (d > 0 ? d + 'd ' + h + 'h' : h + 'h ' + m + 'm');
      el.textContent = label;
      el.classList.toggle('sidebar__session--soon', left < 1800);
      // What the Sign out button says when pointed at (a pill, see pills.js): when the session ends, in the time of the
      // person reading, and what is left. The server wrote it in UTC, once, when the page was made; this keeps it current.
      var link = el.closest('a'), at = new Date(parseInt(el.getAttribute('data-session-expiry'), 10) * 1000);
      if (link && !isNaN(at)) {
        var when = at.toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' });
        var text = left === 0 ? 'Sign out (session expired ' + when + ')' : 'Sign out (session expires ' + when + ', ' + label + ' left)';
        // Only when it changed: pills.js made a pill of the old one, and takes the title again at the next hover
        if ((link.getAttribute('data-bs-original-title') || link.getAttribute('title')) !== text) link.setAttribute('title', text);
      }
    });
  }
  tick();
  setInterval(tick, 30000);
})();

(function() {
  var a = document.documentElement.getAttribute('data-accent') || 'default';
  var s = document.documentElement.getAttribute('data-bs-theme') || 'dark';
  var isDark = s === 'dark';

  // Update toggle
  var btn = document.getElementById('darkModeToggle');
  if (btn) {
    var icon = btn.querySelector('i');
    var span = btn.querySelector('span');
    if (icon) icon.className = isDark ? 'fas fa-sun' : 'fas fa-moon';
    var label = isDark ? 'Switch to light mode' : 'Switch to dark mode';
    btn.setAttribute('title', label);
    btn.setAttribute('aria-label', label);
    btn.setAttribute('aria-pressed', isDark ? 'true' : 'false');
    if (span) span.textContent = isDark ? 'Light mode' : 'Dark mode';
  }

  // Update theme dropdown label
  var td = document.getElementById('themeDropdown');
  if (td) {
    var tdspan = td.querySelector('span');
    if (tdspan) tdspan.textContent = THEME_LABELS[a] || a;
  }

  // Sync custom color picker with the saved color
  var picker = document.getElementById('customColorPicker');
  if (picker) picker.value = getPref('customColor', CUSTOM_ACCENT_DEFAULT);
})();

// The collapsed class is already on <html> (head script): only the pin button needs its label
if (document.documentElement.classList.contains('sidebar-collapsed')) updatePinButton(true);
