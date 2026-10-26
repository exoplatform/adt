(function() {
  var timer = null;
  function hide() {
    clearTimeout(timer);
    document.documentElement.classList.remove('is-loading');
    var el = document.getElementById('pageProgress');
    if (el) el.remove();
  }
  function show() {
    if (document.getElementById('pageProgress')) return;
    var el = document.createElement('div');
    el.id = 'pageProgress';
    el.className = 'page-progress';
    el.setAttribute('role', 'progressbar');
    el.setAttribute('aria-label', 'Loading');
    document.body.appendChild(el);
    document.documentElement.classList.add('is-loading');
    el.offsetWidth; // force a reflow so the width transition starts from 0
    el.classList.add('page-progress--run');
  }
  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(show, 300);
  }
  document.addEventListener('click', function(e) {
    var a = e.target.closest && e.target.closest('a[href]');
    if (!a || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    if ((a.target && a.target !== '_self') || a.hasAttribute('download') || a.origin !== location.origin) return;
    if (a.pathname === location.pathname && a.search === location.search) return;
    schedule();
  });
  document.addEventListener('submit', function(e) {
    if (!e.defaultPrevented) schedule();
  });
  // Back/forward cache restores the page as it was left, bar included
  window.addEventListener('pageshow', hide);
})();

var THEMES = ['default', 'ocean', 'forest', 'rose', 'slate', 'custom'];
// Accents removed over time, mapped to the closest remaining one for returning visitors
var LEGACY_ACCENTS = { twilight: 'default', midnight: 'default', lavender: 'default', gold: 'default', sunset: 'rose', crimson: 'rose' };
var THEME_LABELS = { 'default': 'Default', 'ocean': 'Ocean', 'forest': 'Forest', 'rose': 'Rose', 'slate': 'Slate', 'custom': 'Custom' };
var CUSTOM_ACCENT_DEFAULT = '#6c5ce7';

// ── Storage helpers ──────────────────────────────────
function getPref(key, fallback) { try { var v = localStorage.getItem(key); return v !== null ? v : fallback; } catch(e) { return fallback; } }
function setPref(key, val) { try { localStorage.setItem(key, val); } catch(e) {} }
// Instance pages Card/Table view, applied before first paint to avoid a flash
if (getPref('instances-view', 'cards') === 'table') document.documentElement.classList.add('view-table');
// Collapsed sidebar and install button, also before first paint: set later, the sidebar would be drawn
// expanded and then animate shut on every page, and the footer would jump when the button appears
if (getPref('sidebarCollapsed', '0') === '1') document.documentElement.classList.add('sidebar-collapsed');
if (getPref('pwaInstallable', '0') === '1') document.documentElement.classList.add('pwa-installable');

// ── Resolve stored/effective values ──────────────────
function resolveAccent() {
  var raw = getPref('theme', '');
  if (raw.indexOf(':') > 0) {
    var accent = raw.split(':')[0];
    if (LEGACY_ACCENTS[accent]) return LEGACY_ACCENTS[accent];
    return THEMES.indexOf(accent) >= 0 ? accent : 'default';
  }
  return 'default';
}
function resolveScheme() {
  var raw = getPref('theme', '');
  if (raw.indexOf(':') > 0) return raw.split(':')[1];
  if (raw === 'light' || raw === 'dark') return raw; // backward compat
  return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}
function storeTheme(accent, scheme) { setPref('theme', accent + ':' + scheme); }

// ── Shared themes: ?theme=<accent>:<scheme> or ?theme=custom:<rrggbb>:<scheme> ──
// Strictly validated (known accent, 6-digit hex, light|dark), saved as the visitor's theme,
// then removed from the address bar so it does not linger in bookmarks or copied URLs.
function importSharedTheme() {
  var params, raw;
  try { params = new URLSearchParams(location.search); raw = params.get('theme'); } catch(e) { return; }
  if (raw === null) return;
  var m = /^([a-z]+)(?::([0-9a-f]{6}))?:(light|dark)$/i.exec(raw);
  if (m) {
    var accent = m[1].toLowerCase();
    if (LEGACY_ACCENTS[accent]) accent = LEGACY_ACCENTS[accent];
    if (THEMES.indexOf(accent) >= 0 && (accent === 'custom') === (m[2] !== undefined)) {
      if (accent === 'custom') setPref('customColor', '#' + m[2].toLowerCase());
      storeTheme(accent, m[3].toLowerCase());
    }
  }
  params.delete('theme');
  var qs = params.toString();
  try { history.replaceState(null, '', location.pathname + (qs ? '?' + qs : '') + location.hash); } catch(e) {}
}
importSharedTheme();

// ── Copy text to the clipboard; done(ok) tells whether it worked. The async Clipboard API needs a secure
// context (https or localhost), so instances served over plain http fall back to execCommand ──
function copyText(text, done) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(function() { done(true); }, function() { done(false); });
    return;
  }
  var ta = document.createElement('textarea');
  ta.value = text; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.opacity = '0';
  document.body.appendChild(ta); ta.select();
  var ok = false;
  try { ok = document.execCommand('copy'); } catch(e) {}
  document.body.removeChild(ta);
  done(ok);
}

// ── Copy a link that applies the current theme for whoever opens it ──
function shareTheme(ev) {
  var accent = resolveAccent();
  var scheme = document.documentElement.getAttribute('data-bs-theme') || resolveScheme();
  var color = accent === 'custom' ? getPref('customColor', CUSTOM_ACCENT_DEFAULT).replace('#', '').toLowerCase() + ':' : '';
  var url = location.origin + '/?theme=' + accent + ':' + color + scheme;
  var label = ev && ev.currentTarget ? ev.currentTarget.querySelector('span') : null;
  var done = function(ok) {
    if (!label) return;
    label.textContent = ok ? 'Link copied' : 'Copy failed';
    setTimeout(function() { label.textContent = 'Copy theme link'; }, 1800);
  };
  copyText(url, done);
}

// ── Apply accent (no persist) ────────────────────────
function setAccent(accent) {
  document.documentElement.setAttribute('data-accent', accent);
  if (accent === 'custom') {
    applyCustomColor(getPref('customColor', CUSTOM_ACCENT_DEFAULT));
  } else {
    clearCustomColor();
  }
  var btn = document.getElementById('themeDropdown');
  if (btn) {
    var span = btn.querySelector('span');
    if (span) span.textContent = THEME_LABELS[accent] || accent;
  }
  var picker = document.getElementById('customColorPicker');
  if (picker) picker.value = getPref('customColor', CUSTOM_ACCENT_DEFAULT);
}

// ── Custom colour: only the raw colour is set; style.css derives readable text/fill variants from it ──
function applyCustomColor(hex) {
  if (!/^#[0-9a-f]{6}$/i.test(hex)) hex = CUSTOM_ACCENT_DEFAULT;
  document.documentElement.style.setProperty('--accent-src', hex);
}
function clearCustomColor() {
  document.documentElement.style.removeProperty('--accent-src');
}

// ── Live-preview a custom color without persisting ───
function previewCustomColor(hex) {
  document.documentElement.setAttribute('data-accent', 'custom');
  applyCustomColor(hex);
  var btn = document.getElementById('themeDropdown');
  if (btn) {
    var span = btn.querySelector('span');
    if (span) span.textContent = 'Custom';
  }
}

// ── Commit a custom color pick ───────────────────────
function pickCustomColor(hex) {
  setPref('customColor', hex);
  pickTheme('custom');
}

// ── Full apply: scheme + accent + UI + persist ───────
function applyTheme(accent, scheme, persist) {
  setAccent(accent);
  document.documentElement.setAttribute('data-bs-theme', scheme);
  if (persist) storeTheme(accent, scheme);

  var toggleBtn = document.getElementById('darkModeToggle');
  if (toggleBtn) {
    var isDark = scheme === 'dark';
    var icon = toggleBtn.querySelector('i');
    var span = toggleBtn.querySelector('span');
    var label = isDark ? 'Switch to light mode' : 'Switch to dark mode';
    if (icon) icon.className = isDark ? 'fas fa-sun' : 'fas fa-moon';
    toggleBtn.setAttribute('title', label);
    toggleBtn.setAttribute('aria-label', label);
    toggleBtn.setAttribute('aria-pressed', isDark ? 'true' : 'false');
    if (span) span.textContent = isDark ? 'Light mode' : 'Dark mode';
    if (window.bootstrap) {
      var tip = bootstrap.Tooltip.getInstance(toggleBtn);
      if (tip) tip.dispose();
      new bootstrap.Tooltip(toggleBtn);
    }
  }
  // Update mobile theme icon
  var mobileIcon = document.getElementById('mobileThemeIcon');
  if (mobileIcon) {
    mobileIcon.className = (scheme === 'dark') ? 'fas fa-sun' : 'fas fa-moon';
  }
}

// ── Toggle light/dark scheme ─────────────────────────
function toggleScheme() {
  var curAccent = resolveAccent();
  var curScheme = document.documentElement.getAttribute('data-bs-theme') || 'light';
  applyTheme(curAccent, curScheme === 'dark' ? 'light' : 'dark', true);
}

// ── Pick a new accent theme ──────────────────────────
function pickTheme(accent) {
  var scheme = document.documentElement.getAttribute('data-bs-theme') || resolveScheme();
  applyTheme(accent, scheme, true);
  // Close dropdown + sync aria-expanded
  var dd = document.getElementById('themeDropdownMenu');
  if (dd) dd.classList.remove('show');
  var toggler = document.getElementById('themeDropdown');
  if (toggler) toggler.setAttribute('aria-expanded', 'false');
}

// ── Initialise immediately (FOUC guard) ──────────────
(function() {
  var accent = resolveAccent();
  document.documentElement.setAttribute('data-accent', accent);
  if (accent === 'custom') {
    applyCustomColor(getPref('customColor', CUSTOM_ACCENT_DEFAULT));
  }
  document.documentElement.setAttribute('data-bs-theme', resolveScheme());
  // Init mobile theme icon
  var mIcon = document.getElementById('mobileThemeIcon');
  if (mIcon) {
    mIcon.className = resolveScheme() === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
  }
})();

// ── Listen for system scheme changes ─────────────────
if (window.matchMedia) {
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function(e) {
    var raw = getPref('theme', '');
    if (raw === '' || raw === 'light' || raw === 'dark') {
      var a = resolveAccent();
      var s = e.matches ? 'dark' : 'light';
      applyTheme(a, s, false);
    }
  });
}

// ── Mobile sidebar ───────────────────────────────────
function toggleSidebar() {
  var sb = document.getElementById('sidebar');
  var overlay = document.getElementById('sidebarOverlay');
  if (sb && overlay) {
    sb.classList.toggle('open');
    overlay.classList.toggle('show');
    document.body.style.overflow = sb.classList.contains('open') ? 'hidden' : '';
  }
}

// ── Sidebar pin/unpin ────────────────────────────────
function toggleSidebarPin() {
  var collapsed = document.documentElement.classList.toggle('sidebar-collapsed');
  setPref('sidebarCollapsed', collapsed ? '1' : '0');
  updatePinButton(collapsed);
}
function updatePinButton(collapsed) {
  var btn = document.getElementById('sidebarPinBtn');
  if (!btn) return;
  var icon = btn.querySelector('i');
  var span = btn.querySelector('span');
  if (collapsed) {
    if (icon) icon.className = 'fas fa-chevron-right';
    if (span) span.textContent = 'Expand';
    btn.setAttribute('title', 'Expand sidebar');
  } else {
    if (icon) icon.className = 'fas fa-chevron-left';
    if (span) span.textContent = 'Collapse';
    btn.setAttribute('title', 'Collapse sidebar');
  }
}
// ── Instance search ──────────────────────────────────
function initSearch() {
  var searchInput = document.getElementById('instanceSearch');
  if (!searchInput) return;
  // Restore saved query
  var pageKey = 'search-' + window.location.pathname;
  var saved = getPref(pageKey, '');
  if (saved) { searchInput.value = saved; doSearch(saved); }
  searchInput.addEventListener('input', function() {
    var query = this.value;
    setPref(pageKey, query);
    doSearch(query);
  });
}
function doSearch(raw) {
  var query = raw.toLowerCase().trim();
  document.querySelectorAll('.instances-section').forEach(function(section) {
    var visible = 0;
    section.querySelectorAll('.instance-card').forEach(function(card) {
      if (!query) {
        card.classList.remove('hidden');
        visible++;
      } else {
        var name = (card.querySelector('.instance-card__name') || {}).textContent || '';
        var meta = (card.querySelector('.instance-card__meta') || {}).textContent || '';
        var feature = (card.querySelector('.instance-card__feature') || {}).textContent || '';
        var haystack = (name + ' ' + meta + ' ' + feature).toLowerCase();
        if (haystack.indexOf(query) === -1) {
          card.classList.add('hidden');
        } else {
          card.classList.remove('hidden');
          visible++;
        }
      }
    });
    section.classList.toggle('empty', query && visible === 0);
  });
}
// ── Truncated versions: show the full version in their tooltip ──
// The version text is ellipsed when its column is too narrow; prepend the
// full text to its tooltip (the build timestamp/CD details) only then.
function syncVersionTitles() {
  document.querySelectorAll('.instance-card__meta .text-mono').forEach(function(el) {
    var tip = window.bootstrap && bootstrap.Tooltip.getInstance(el);
    var attr = tip ? 'data-bs-original-title' : 'title';
    if (!el.hasAttribute('data-version-detail')) {
      el.setAttribute('data-version-detail', el.getAttribute(attr) || el.getAttribute('title') || '');
    }
    var detail = el.getAttribute('data-version-detail');
    var full = el.textContent.trim();
    var text = el.scrollWidth > el.clientWidth && full !== detail
      ? full + (detail ? ' \u2014 ' + detail : '')
      : detail;
    if (text) el.setAttribute(attr, text); else el.removeAttribute(attr);
  });
}
// ── Instance Card/Table view switch ──────────────────
function initViewSwitch() {
  var search = document.querySelector('.instances-search');
  if (!search || !document.getElementById('instanceSearch') || !document.querySelector('.instance-grid')) return;
  // Toolbar: search + view switch
  var toolbar = document.createElement('div');
  toolbar.className = 'instances-toolbar';
  search.parentNode.insertBefore(toolbar, search);
  toolbar.appendChild(search);
  var group = document.createElement('div');
  group.className = 'btn-group btn-group-sm instances-view-switch';
  group.setAttribute('role', 'group');
  group.setAttribute('aria-label', 'Instances view');
  group.innerHTML =
    '<button type="button" class="btn btn-outline-secondary" data-view="cards" title="Card view"><i class="fas fa-th-large me-1"></i>Cards</button>' +
    '<button type="button" class="btn btn-outline-secondary" data-view="table" title="Table view"><i class="fas fa-list me-1"></i>Table</button>';
  toolbar.appendChild(group);
  // Column headers, only displayed in table view
  document.querySelectorAll('.instance-grid').forEach(function(grid) {
    var head = document.createElement('div');
    head.className = 'instance-table-head';
    head.setAttribute('aria-hidden', 'true');
    head.innerHTML =
      '<button type="button" data-sort="status" title="Sort by status"><span class="visually-hidden">Status</span></button>' +
      '<button type="button" data-sort="name">Instance</button>' +
      '<button type="button" data-sort="version">Version</button>' +
      '<button type="button" data-sort="deployed" title="Sort by deployment date">Database / Deployed</button>' +
      '<span>Badges</span><span></span><span>Actions</span>';
    grid.insertBefore(head, grid.firstChild);
  });
  // Each section is its own grid: share the widest tools/actions columns
  // across all of them so the table columns line up from one section to the next
  function syncColumns() {
    var root = document.documentElement.style;
    root.removeProperty('--instance-tools-w');
    root.removeProperty('--instance-actions-w');
    if (!document.documentElement.classList.contains('view-table')) return;
    var tools = 0, actions = 0;
    document.querySelectorAll('.instance-grid').forEach(function(grid) {
      if (!grid.offsetParent) return;
      var cols = getComputedStyle(grid).gridTemplateColumns.match(/[\d.]+px/g);
      if (!cols || cols.length < 2) return;
      tools = Math.max(tools, parseFloat(cols[cols.length - 2]));
      actions = Math.max(actions, parseFloat(cols[cols.length - 1]));
    });
    if (tools) root.setProperty('--instance-tools-w', Math.ceil(tools) + 'px');
    if (actions) root.setProperty('--instance-actions-w', Math.ceil(actions) + 'px');
  }
  // ── Table sorting: per section, via CSS order (table view only, the
  // card view keeps the server order); "key:asc|desc", saved per browser
  var collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });
  function sortValue(card, key) {
    if (key === 'name') return (card.querySelector('.instance-card__name') || {}).textContent.trim();
    return card.getAttribute('data-sort-' + key) || '';
  }
  function applySort(sort) {
    var parts = (sort || '').split(':'), key = parts[0], dir = parts[1] === 'desc' ? -1 : 1;
    document.querySelectorAll('.instance-grid').forEach(function(grid) {
      var cards = [].slice.call(grid.querySelectorAll('.instance-card'));
      if (key) {
        cards.sort(function(a, b) {
          var va = sortValue(a, key), vb = sortValue(b, key);
          // Empty values always last
          if (!va !== !vb) return va ? -1 : 1;
          return collator.compare(va, vb) * dir;
        });
      }
      cards.forEach(function(card, i) {
        if (key) card.style.setProperty('--sort-order', i + 1); else card.style.removeProperty('--sort-order');
      });
      grid.querySelectorAll('.instance-table-head [data-sort]').forEach(function(btn) {
        var on = btn.getAttribute('data-sort') === key;
        btn.classList.toggle('sorted', on);
        btn.setAttribute('data-dir', on ? (dir === 1 ? 'asc' : 'desc') : '');
        btn.setAttribute('aria-sort', on ? (dir === 1 ? 'ascending' : 'descending') : 'none');
      });
    });
  }
  document.addEventListener('click', function(e) {
    var btn = e.target.closest('.instance-table-head [data-sort]');
    if (!btn) return;
    // Cycle: ascending -> descending -> server order
    var key = btn.getAttribute('data-sort'), current = getPref('instances-sort', '');
    var next = current === key + ':asc' ? key + ':desc' : (current === key + ':desc' ? '' : key + ':asc');
    setPref('instances-sort', next);
    applySort(next);
  });
  applySort(getPref('instances-sort', ''));
  function apply(view) {
    document.documentElement.classList.toggle('view-table', view === 'table');
    group.querySelectorAll('[data-view]').forEach(function(b) {
      var on = b.getAttribute('data-view') === view;
      b.classList.toggle('active', on);
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    syncColumns();
    syncVersionTitles();
  }
  var resizeTimer;
  window.addEventListener('resize', function() {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function() {
      syncColumns();
      syncVersionTitles();
    }, 150);
  });
  group.addEventListener('click', function(e) {
    var btn = e.target.closest('[data-view]');
    if (!btn) return;
    setPref('instances-view', btn.getAttribute('data-view'));
    apply(btn.getAttribute('data-view'));
  });
  apply(getPref('instances-view', 'cards'));
}
function initInstances() {
  initViewSwitch();
  initSearch();
}
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initInstances);
} else {
  initInstances();
}

// Crowdin Cards/Table view, applied before first paint
if (getPref('crowdin-view', 'cards') === 'table') document.documentElement.classList.add('crowdin-table-view');

// ── Actions of the buttons and fields (data-click / data-input / data-change="name", data-arg="value"):
// the page carries no inline handler, so it can be served with a Content-Security-Policy without 'unsafe-inline'
window.ADT_ACTIONS = {
  toggleSidebar: function() { toggleSidebar(); },
  toggleSidebarPin: function() { toggleSidebarPin(); },
  toggleScheme: function() { toggleScheme(); },
  pickTheme: function(arg) { pickTheme(arg); },
  shareTheme: function(arg, e) { shareTheme(e); },
  previewCustomColor: function(arg, e, el) { previewCustomColor(el.value); },
  pickCustomColor: function(arg, e, el) { pickCustomColor(el.value); }
};
['click', 'input', 'change'].forEach(function(type) {
  document.addEventListener(type, function(e) {
    var el = e.target.closest && e.target.closest('[data-' + type + ']');
    var fn = el && window.ADT_ACTIONS[el.getAttribute('data-' + type)];
    if (fn) fn(el.getAttribute('data-arg'), e, el);
  });
});
// A select that applies itself, and a form that asks first. The confirmation runs while the event goes down, so the
// loading bar above (which listens on the way up) is not shown for a cancelled form.
document.addEventListener('change', function(e) {
  if (e.target.closest && e.target.closest('[data-autosubmit]')) e.target.form.submit();
});
document.addEventListener('submit', function(e) {
  var message = e.target.getAttribute && e.target.getAttribute('data-confirm');
  if (message && !window.confirm(message)) e.preventDefault();
}, true);
