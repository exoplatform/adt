<?php
require_once(dirname(__FILE__) . '/functions-ui-form-edit-fb.php');
require_once(dirname(__FILE__) . '/functions-ui-form-edit-note.php');

/**
 * Insert the page header lines
 *
 * @param string $title the title of the page (default: none)
 * @param bool $autoRefresh whether to auto-reload the page every 2 minutes (default: true).
 *                          Disable this on pages with their own live-updating JS state
 *                          (e.g. log streaming) that a full page reload would reset.
 */
function pageHeader($title = "", $autoRefresh = true)
{
?>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <?php if ($autoRefresh) { ?>
  <meta http-equiv="refresh" content="120">
  <?php } ?>
  <meta name="theme-color" content="#6c5ce7">
  <title>eXo Acceptance<?= (empty($title) ? "" : " · " . $title) ?></title>
  <link rel="apple-touch-icon" sizes="180x180" href="/images/apple-touch-icon.png" />
  <link rel="icon" type="image/png" sizes="48x48" href="/images/favicon-48x48.png" />
  <link rel="icon" type="image/png" sizes="32x32" href="/images/favicon-32x32.png" />
  <link rel="icon" type="image/png" sizes="16x16" href="/images/favicon-16x16.png" />
  <link rel="icon" type="image/x-icon" href="/images/favicon.ico" />
  <link rel="manifest" href="/manifest.json">
  <!-- Bootstrap 5 CSS -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <!-- Font Awesome 6 -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
  <!-- Custom CSS -->
  <link href="./style.css" media="screen" rel="stylesheet" type="text/css" />
  <!-- jQuery -->
  <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
  <!-- Bootstrap 5 JS Bundle with Popper -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
  <!-- Theme handling -->
  <script>
    var THEMES = ['default', 'ocean', 'forest', 'twilight', 'sunset', 'midnight', 'lavender', 'crimson'];
    var THEME_LABELS = { 'default': 'Default', 'ocean': 'Ocean', 'forest': 'Forest', 'twilight': 'Twilight', 'sunset': 'Sunset', 'midnight': 'Midnight', 'lavender': 'Lavender', 'crimson': 'Crimson' };

    // ── Storage helpers ──────────────────────────────────
    function getPref(key, fallback) { try { var v = localStorage.getItem(key); return v !== null ? v : fallback; } catch(e) { return fallback; } }
    function setPref(key, val) { try { localStorage.setItem(key, val); } catch(e) {} }

    // ── Resolve stored/effective values ──────────────────
    function resolveAccent() {
      var raw = getPref('theme', '');
      if (raw.indexOf(':') > 0) return raw.split(':')[0];
      return 'default';
    }
    function resolveScheme() {
      var raw = getPref('theme', '');
      if (raw.indexOf(':') > 0) return raw.split(':')[1];
      if (raw === 'light' || raw === 'dark') return raw; // backward compat
      return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    function storeTheme(accent, scheme) { setPref('theme', accent + ':' + scheme); }

    // ── Apply accent (no persist) ────────────────────────
    function setAccent(accent) {
      document.documentElement.setAttribute('data-accent', accent);
      var btn = document.getElementById('themeDropdown');
      if (btn) {
        var span = btn.querySelector('span');
        if (span) span.textContent = THEME_LABELS[accent] || accent;
      }
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
        var tip = bootstrap.Tooltip.getInstance(toggleBtn);
        if (tip) tip.dispose();
        new bootstrap.Tooltip(toggleBtn);
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
      document.documentElement.setAttribute('data-accent', resolveAccent());
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
      var collapsed = document.body.classList.toggle('sidebar-collapsed');
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
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initSearch);
    } else {
      initSearch();
    }
  </script>
<?php
}


/**
 * Insert the script tag for Google Analytics tracking
 *
 * @param string $id the google tracker id
 */
function pageTracker($id = 'UA-1292368-28') {
?>
  <script>
    (function(i, s, o, g, r, a, m) {
      i['GoogleAnalyticsObject'] = r;
      i[r] = i[r] || function() {
        (i[r].q = i[r].q || []).push(arguments)
      }, i[r].l = 1 * new Date();
      a = s.createElement(o),
        m = s.getElementsByTagName(o)[0];
      a.async = 1;
      a.src = g;
      m.parentNode.insertBefore(a, m)
    })(window, document, 'script', 'https://www.google-analytics.com/analytics.js', 'ga');

    ga('create', '<?= $id ?>', 'auto');
    ga('send', 'pageview');
  </script>
<?php
}

/**
 * Insert the navigation sidebar
 */
function pageNavigation()
{
  $nav = [
    "Home" => "/",
    "QA" => "/qa.php",
    "Sales" => "/sales.php",
    "Customer Projects" => "/customers.php",
    "Company" => "/company.php",
    "Features" => "/features.php",
    "Git Activity" => "/git-activity.php",
    "Crowdin" => "/crowdin-health.php",
    "Servers" => "/servers.php",
  ];
  $icons = [
    "Home" => "fa-th-large",
    "QA" => "fa-flask",
    "Sales" => "fa-chart-line",
    "Customer Projects" => "fa-briefcase",
    "Company" => "fa-building",
    "Features" => "fa-code-branch",
    "Git Activity" => "fa-code-commit",
    "Crowdin" => "fa-language",
    "Servers" => "fa-server",
  ];

?>
  <!-- Skip to main content -->
  <a href="#main" class="skip-to-content sr-only-focusable">
    <i class="fas fa-arrow-down me-1" aria-hidden="true"></i>Skip to main content
  </a>

  <!-- Mobile top bar -->
  <div class="mobile-bar d-md-none">
    <button class="mobile-bar__btn" onclick="toggleSidebar()" aria-label="Open navigation menu">
      <i class="fas fa-bars"></i>
    </button>
    <span class="mobile-bar__brand" title="<?= htmlspecialchars($_SERVER['SERVER_NAME']) ?>">Acceptance</span>
    <div class="mobile-bar__actions">
      <button class="mobile-bar__theme-btn" onclick="toggleScheme()" aria-label="Toggle dark mode" title="Toggle dark mode">
        <i class="fas fa-moon" id="mobileThemeIcon"></i>
      </button>
    </div>
  </div>

  <!-- Sidebar overlay (mobile) -->
  <div class="sidebar-overlay d-md-none" id="sidebarOverlay" onclick="toggleSidebar()"></div>

  <!-- Sidebar -->
  <aside class="sidebar" id="sidebar" aria-label="Main navigation">
    <a class="sidebar__brand" href="/" title="Home">
      <div class="sidebar__brand-icon" style="background:transparent">
        <img src="/images/icon-192.png" alt="eXo" width="28" height="28" srcset="/images/icon-192.png 2x, /images/icon-512.png 3x">
      </div>
      <div class="sidebar__brand-info">
        <div class="sidebar__brand-text" title="<?= htmlspecialchars($_SERVER['SERVER_NAME']) ?>">Acceptance</div>
        <div class="sidebar__brand-version"><?= htmlspecialchars($_SERVER['SERVER_NAME']) ?></div>
      </div>
    </a>

    <nav class="sidebar__nav">
      <div class="sidebar__section">Navigation</div>
      <?php
      foreach ($nav as $label => $url) {
        $active = ($url == $_SERVER['REQUEST_URI']) ? 'active' : '';
        $ariaCurrent = ($url == $_SERVER['REQUEST_URI']) ? ' aria-current="page"' : '';
        $icon = isset($icons[$label]) ? $icons[$label] : 'fa-circle';
        echo '<a class="sidebar__link ' . $active . '" href="' . $url . '"' . $ariaCurrent . ' title="' . $label . '">';
        echo '<i class="fas ' . $icon . ' sidebar__icon" aria-hidden="true"></i>';
        echo '<span>' . $label . '</span>';
        echo '</a>';
      }
      ?>
    </nav>

    <div class="sidebar__footer">
      <!-- Pin/unpin toggle -->
      <button class="sidebar__footer-btn" id="sidebarPinBtn" onclick="toggleSidebarPin()" title="Collapse sidebar">
        <i class="fas fa-chevron-left"></i> <span>Collapse</span>
      </button>

      <!-- Theme accent dropdown -->
      <div class="dropdown dropup">
        <button class="sidebar__footer-btn dropdown-toggle" id="themeDropdown" data-bs-toggle="dropdown" data-bs-display="static" aria-expanded="false" aria-label="Select theme" title="Change theme">
          <i class="fas fa-palette"></i> <span>Default</span>
        </button>
        <ul class="dropdown-menu" id="themeDropdownMenu" aria-labelledby="themeDropdown" style="min-width:160px">
          <li><button class="dropdown-item" onclick="pickTheme('default')"><i class="fas fa-circle me-2" style="color:#6c5ce7;font-size:0.65rem"></i>Default</button></li>
          <li><button class="dropdown-item" onclick="pickTheme('ocean')"><i class="fas fa-circle me-2" style="color:#0ea5e9;font-size:0.65rem"></i>Ocean</button></li>
          <li><button class="dropdown-item" onclick="pickTheme('forest')"><i class="fas fa-circle me-2" style="color:#10b981;font-size:0.65rem"></i>Forest</button></li>
          <li><button class="dropdown-item" onclick="pickTheme('twilight')"><i class="fas fa-circle me-2" style="color:#8b5cf6;font-size:0.65rem"></i>Twilight</button></li>
          <li><hr class="dropdown-divider"></li>
          <li><button class="dropdown-item" onclick="pickTheme('sunset')"><i class="fas fa-circle me-2" style="color:#f97316;font-size:0.65rem"></i>Sunset</button></li>
          <li><button class="dropdown-item" onclick="pickTheme('midnight')"><i class="fas fa-circle me-2" style="color:#6366f1;font-size:0.65rem"></i>Midnight</button></li>
          <li><button class="dropdown-item" onclick="pickTheme('lavender')"><i class="fas fa-circle me-2" style="color:#c084fc;font-size:0.65rem"></i>Lavender</button></li>
          <li><button class="dropdown-item" onclick="pickTheme('crimson')"><i class="fas fa-circle me-2" style="color:#ef4444;font-size:0.65rem"></i>Crimson</button></li>
        </ul>
      </div>

      <!-- Light/dark toggle -->
      <button class="sidebar__footer-btn" id="darkModeToggle" onclick="toggleScheme()" title="Switch to light mode" aria-label="Switch to light mode" aria-pressed="false">
        <i class="fas fa-sun" aria-hidden="true"></i> <span>Light mode</span>
      </button>

      <!-- PWA Install -->
      <button class="sidebar__footer-btn" id="pwaInstallBtn" onclick="pwaInstall()" title="Install app" style="display:none">
        <i class="fas fa-download"></i> <span>Install app</span>
      </button>
    </div>

    <script>
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
          var name = ({'default':'Default','ocean':'Ocean','forest':'Forest','twilight':'Twilight','sunset':'Sunset','midnight':'Midnight','lavender':'Lavender','crimson':'Crimson'}[a]) || a;
          if (tdspan) tdspan.textContent = name;
        }
      })();
    </script>
  </aside>

  <script>
    // Restore sidebar collapse state
    if (getPref('sidebarCollapsed', '0') === '1') {
      document.body.classList.add('sidebar-collapsed');
      updatePinButton(true);
    }
  </script>
<?php
}


/**
 * Insert the Footer
 */
function pageFooter() {
?>
  <!-- Footer ================================================== -->
  <footer id="footer" role="contentinfo">
    <span class="sr-only">Copyright</span> &copy; 2006-<?= date("Y") ?> eXo Platform SAS
    <a href="/stats/awstats.pl?config=<?= $_SERVER['SERVER_NAME'] ?>" target="_blank" aria-label="View statistics" class="ms-3">
      <i class="fas fa-chart-bar" aria-hidden="true"></i> Stats
    </a>
  </footer>
  <script type="text/javascript">
    $(document).ready(function() {
      // Initialize Bootstrap tooltips
      var tooltipTriggerList = [].slice.call(document.querySelectorAll('[rel=tooltip]'));
      var tooltipList = tooltipTriggerList.map(function(tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
      });

      // Initialize Bootstrap popovers with HTML support
      var popoverTriggerList = [].slice.call(document.querySelectorAll('[rel=popover]'));
      var popoverList = popoverTriggerList.map(function(popoverTriggerEl) {
        return new bootstrap.Popover(popoverTriggerEl, {
          trigger: 'hover',
          html: true,
          sanitize: false,
          container: 'body',
          animation: true,
          delay: {
            show: 100,
            hide: 100
          }
        });
      });
    });

    // Service Worker registration with update handling
    if ('serviceWorker' in navigator) {
      var updateToast = null;

      function showUpdateToast() {
        if (updateToast) return;
        var toast = document.createElement('div');
        toast.id = 'pwa-update-toast';
        toast.innerHTML = '<i class="fas fa-sync-alt"></i> New version available \u2014 click to refresh';
        toast.onclick = function() { window.doUpdate(); };
        document.body.appendChild(toast);
        updateToast = toast;
      }

      window.doUpdate = function() {
        if (window.waitingWorker) {
          window.waitingWorker.postMessage({ action: 'skipWaiting' });
        }
      };

      navigator.serviceWorker.register('/sw.js').then(function(reg) {
        if (reg.waiting) {
          window.waitingWorker = reg.waiting;
          showUpdateToast();
        }
        reg.addEventListener('updatefound', function() {
          var newWorker = reg.installing;
          if (!newWorker) return;
          newWorker.addEventListener('statechange', function() {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              window.waitingWorker = newWorker;
              showUpdateToast();
            }
          });
        });
      });

      var refreshing = false;
      navigator.serviceWorker.addEventListener('controllerchange', function() {
        if (refreshing) return;
        refreshing = true;
        window.location.reload();
      });
    }

    // PWA Install prompt
    var deferredPrompt;
    window.addEventListener('beforeinstallprompt', function(e) {
      e.preventDefault();
      deferredPrompt = e;
      var btn = document.getElementById('pwaInstallBtn');
      if (btn) btn.style.display = '';
    });
    function pwaInstall() {
      if (!deferredPrompt) return;
      deferredPrompt.prompt();
      deferredPrompt.userChoice.then(function(result) {
        if (result.outcome === 'accepted') {
          var btn = document.getElementById('pwaInstallBtn');
          if (btn) btn.style.display = 'none';
        }
        deferredPrompt = null;
      });
    }
    // Already running installed (standalone): never show the install button.
    if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) {
      var pwaBtn = document.getElementById('pwaInstallBtn');
      if (pwaBtn) pwaBtn.style.display = 'none';
    }
  </script>
<?php
}

function buildTableTitleDev($plf_branch) {
  switch ($plf_branch) {
    case "1.0.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "1.1.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;  
    case "1.2.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "1.3.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "1.4.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "1.5.x":
      $content="Platform " . $plf_branch . " based builds (Meeds)";
      break;
    case "4.0.x":
    case "4.1.x":
    case "4.2.x":
    case "4.3.x":
    case "4.4.x":
    case "5.0.x":
    case "5.1.x":
    case "5.2.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;
    case "5.3.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;
    case "6.0.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
       break;  
    case "6.1.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "6.2.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "6.3.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "6.4.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "6.5.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "7.0.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "7.1.x":
      $content="Platform " . $plf_branch . " based builds (Maintenance)";
      break;
    case "7.2.x":
      $content="Platform or Meeds " . $plf_branch . " based builds (Maintenance)";
      break;  
    case "7.3.x":
      $content="Platform or Meeds " . $plf_branch . " based builds (R&D) - next product release (no date yet)";
      break;    
    case "5.x":
      $content="Platform " . $plf_branch . " based builds (R&D) - perhaps next features ;-)"; 
      break;
    case "4.0.x Demo":
    case "4.1.x Demo":
    case "4.2.x Demo":
    case "4.3.x Demo":
    case "4.4.x Demo":
    case "5.0.x Demo":
    case "5.1.x Demo":
    case "5.2.x Demo":
    case "5.3.x Demo":
      $content="Platform " . $plf_branch . "s";
      break;
    case "COMPANY":
      $content="Company internal projects";
      break;
    case "CODEFEST":
      $content="eXo Codefest";
      break;
    case "UNKNOWN":
      $content="Unclassified projects";
      break;
    default:
      $content="Platform " . $plf_branch . " based build (Unclassified)";
  }
  return $content;
}

/**
 * Return the markup for labels
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentLabels ($deployment_descriptor) {
  $content="";
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_LABELS')) {
    if (is_array($deployment_descriptor->DEPLOYMENT_LABELS)) {
      $labels = $deployment_descriptor->DEPLOYMENT_LABELS;
    } else {
      $labels[] = $deployment_descriptor->DEPLOYMENT_LABELS;
    }
    foreach ($labels as $label) {
      $content.='<span class="label label-label">'.htmlspecialchars($label).'</span>&nbsp;';
    }
  }
  return $content;
}

/**
 * Return the markup for addons labels
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentAddonsTags($deployment_descriptor)
{
  $content = "";
  $content .= componentAddonsDistributionTags($deployment_descriptor) . " ";

  if (property_exists($deployment_descriptor, 'DEPLOYMENT_ADDONS')) {
    if (is_array($deployment_descriptor->DEPLOYMENT_ADDONS)) {
      $labels = $deployment_descriptor->DEPLOYMENT_ADDONS;
    } else {
      $labels[] = $deployment_descriptor->DEPLOYMENT_ADDONS;
    }
    foreach ($labels as $label) {
      $label_array = explode(':', $label, 2);
      $version = isset($label_array[1]) ? $label_array[1] : 'latest';
      $content .= '<span class="badge bg-info" rel="tooltip" title="version: ' . htmlspecialchars($version) . '">' . htmlspecialchars($label_array[0]) . '</span> ';
    }
  }
  return $content;
}

/**
 * Return the markup for distribution addons labels
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentAddonsDistributionTags($deployment_descriptor)
{
  return '<span class="badge bg-secondary" rel="tooltip" title="distribution add-ons: ' . htmlspecialchars($deployment_descriptor->PRODUCT_ADDONS_DISTRIB) . '"><i class="fas fa-gift"></i></span>';
}

/**
 * Return the markup for a boolean deployment-descriptor flag, as either a bare
 * tooltipped icon or a badge-wrapped tooltipped icon.
 *
 * Shared by componentUpgradeEligibility(), componentPatchInstallation(),
 * componentStagingModeEnabled(), componentDevModeEnabled(),
 * componentDebugModeEnabled() and componentCertbotEnabled(), which only differ
 * in which descriptor property they check and which icon/badge/tooltip to use.
 *
 * @param $deployment_descriptor
 * @param string $property       the boolean-ish descriptor property to check
 * @param string $icon_class     Font Awesome icon class
 * @param string $badge_class    Bootstrap badge color class (used when $is_label_addon is true)
 * @param string $tooltip        tooltip text (may reference the property's own value)
 * @param bool   $is_label_addon whether to wrap the icon in a badge
 *
 * @return string html markup
 */
function componentFlagBadge($deployment_descriptor, $property, $icon_class, $badge_class, $tooltip, $is_label_addon = true)
{
  if (property_exists($deployment_descriptor, $property) && $deployment_descriptor->$property) {
    $class = $is_label_addon ? ' class="badge ' . $badge_class . '"' : '';
    return '<span' . $class . ' rel="tooltip" title="' . htmlspecialchars($tooltip) . '"><i class="' . $icon_class . '"></i></span>';
  }
  return '';
}

/**
 * Return the markup for instance upgrades eligiblity
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentUpgradeEligibility($deployment_descriptor, $is_label_addon = true)
{
  return componentFlagBadge($deployment_descriptor, 'INSTANCE_TOKEN', 'fas fa-flag', 'bg-info',
    'This instance is eligible for upgrades.', $is_label_addon);
}

/**
 * Return the markup for instance patch installation
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentPatchInstallation($deployment_descriptor, $is_label_addon = true)
{
  return componentFlagBadge($deployment_descriptor, 'DEPLOYMENT_PATCHES', 'fas fa-plus-circle', 'bg-success',
    (property_exists($deployment_descriptor, 'DEPLOYMENT_PATCHES') ? $deployment_descriptor->DEPLOYMENT_PATCHES : '') . ' is installed on this instance.',
    $is_label_addon);
}
/**
 * Return the markup for staging instance
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentStagingModeEnabled($deployment_descriptor, $is_label_addon = true)
{
  return componentFlagBadge($deployment_descriptor, 'DEPLOYMENT_STAGING_ENABLED', 'fas fa-fire', 'bg-warning',
    'This instance is enabled with Staging mode.', $is_label_addon);
}

/**
 * Return the markup for instance dev mode availability
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDevModeEnabled($deployment_descriptor, $is_label_addon = true)
{
  return componentFlagBadge($deployment_descriptor, 'DEPLOYMENT_DEV_ENABLED', 'fab fa-github', 'bg-dark',
    'This instance is enabled with Dev mode.', $is_label_addon);
}

/**
 * Return the markup for instance debug mode availability
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDebugModeEnabled($deployment_descriptor, $is_label_addon = true)
{
  return componentFlagBadge($deployment_descriptor, 'DEPLOYMENT_DEBUG_ENABLED', 'fas fa-stethoscope', 'bg-danger',
    'This instance is enabled with Debug mode.', $is_label_addon);
}

/**
 * Return the markup for instance certbot availability
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentCertbotEnabled($deployment_descriptor, $is_label_addon = true)
{
  return componentFlagBadge($deployment_descriptor, 'DEPLOYMENT_CERTBOT_ENABLED', 'fas fa-certificate', 'bg-primary',
    'This instance SSL certificate is generated by certbot.', $is_label_addon);
}

/**
 * Return the markup for the Deployment Status
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentStatusIcon($deployment_descriptor) {
  if ($deployment_descriptor->DEPLOYMENT_STATUS == "Up") {
    return '<i class="fas fa-circle text-success" rel="tooltip" title="Status: Up" aria-label="Status: Up" role="img"></i>';
  } else {
    return '<i class="fas fa-circle text-danger" rel="tooltip" title="Status: Down" aria-label="Status: Down" role="img"></i>';
  }
}

/**
 * Return markup for the Application Server type
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentAppServerIcon($deployment_descriptor) {
  $icons = [
    'tomcat' => 'fa-brands fa-java',
    'jboss' => 'fa-brands fa-redhat',
    'wildfly' => 'fa-brands fa-redhat',
  ];

  $type = strtolower($deployment_descriptor->DEPLOYMENT_APPSRV_TYPE);
  $icon = $icons[$type] ?? 'fa-server';

  return '<i class="fas ' . $icon . '" rel="tooltip" title="Application Server: ' . htmlspecialchars($deployment_descriptor->DEPLOYMENT_APPSRV_TYPE) . '"></i>';
}
/**
 * Get the markup for the Edit Note icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentEditNoteIcon($deployment_descriptor)
{
  $modalId = 'edit-note-' . str_replace(".", "_", $deployment_descriptor->INSTANCE_KEY);
  $content = '<a href="javascript:void(0)" data-bs-toggle="modal" data-bs-target="#' . $modalId . '" title="Edit note"><i class="fas fa-pencil-alt"></i></a>';
  $content .= getFormEditNote($deployment_descriptor);
  return $content;
}

/**
 * Get the markup for the Specification link icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup or empty if no specification on the deployment
 */
function componentSpecificationIcon($deployment_descriptor)
{
  if (!empty($deployment_descriptor->SPECIFICATIONS_LINK)) {
    return '<a rel="tooltip" title="Specifications link" href="' . htmlspecialchars($deployment_descriptor->SPECIFICATIONS_LINK) . '" target="_blank"><i class="fas fa-book"></i></a>';
  }
  return '';
}


/**
 * Return markup for the Database type icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDatabaseIcon($deployment_descriptor)
{
  $db_types = [
    'mysql'    => ['MySQL', 'text-primary'],
    'mariadb'  => ['MariaDB', 'text-success'],
    'postgres' => ['PostgreSQL', 'text-info'],
    'oracle'   => ['Oracle', 'text-danger'],
    'sqlserver'=> ['SQL Server', 'text-warning'],
    'h2'       => ['H2', 'text-secondary'],
    'hsql'     => ['HSQLDB', 'text-secondary'],
  ];

  $db_type = null;
  $icon_color = 'text-secondary';
  foreach ($db_types as $needle => [$label, $color]) {
    if (stripos($deployment_descriptor->DATABASE, $needle) !== false) {
      $db_type = $label;
      $icon_color = $color;
      break;
    }
  }

  $content = "";
  if ($db_type !== null) {
    $content .= '<i class="fas fa-database ' . $icon_color . '" rel="tooltip" title="' . htmlspecialchars($db_type) . '"></i>&nbsp;';
  } else {
    $content .= '<i class="fas fa-database text-muted" rel="tooltip" title="No database"></i>&nbsp;';
  }

  if (empty($deployment_descriptor->DEPLOYMENT_DATABASE_VERSION)) {
    $content .= '<span class="badge bg-secondary">-NC-</span>';
  } else {
    $content .= '<span class="badge bg-info">' . htmlspecialchars($deployment_descriptor->DEPLOYMENT_DATABASE_VERSION) . '</span>';
  }

  return $content;
}

/**
 * Return markup for the Visibility icon
 *
 * @param $deployment_descriptor
 * @param $color The color for the icon (default: none)
 *
 * @return string html markup
 */
function componentVisibilityIcon($deployment_descriptor, $color = "")
{
  if ($deployment_descriptor->DEPLOYMENT_APACHE_SECURITY === "public") {
    $icon = "fa-globe";
  } else if ($deployment_descriptor->DEPLOYMENT_APACHE_SECURITY === "private") {
    $icon = "fa-lock";
  } else {
    $icon = "fa-question-circle";
  }
  
  $colorClass = empty($color) ? '' : ' text-' . $color;
  return '<i class="fas ' . $icon . $colorClass . '" rel="tooltip" title="Visibility: ' . $deployment_descriptor->DEPLOYMENT_APACHE_SECURITY . '"></i>';
}

/**
 * Get the markup for the Product Info icon with popover
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentProductInfoIcon($deployment_descriptor)
{
  return '<a href="#" rel="popover" data-bs-content="' . htmlspecialchars(componentProductHtmlPopover($deployment_descriptor)) . '" data-bs-html="true" data-bs-trigger="hover"><i class="fas fa-info-circle text-info"></i></a>';
}

/**
 * Insert markup for the Artifact download icon link
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDownloadIcon($deployment_descriptor)
{
  $data_content = "<strong>GroupId:</strong> " . $deployment_descriptor->ARTIFACT_GROUPID . "<br/>";
  $data_content .= "<strong>ArtifactId:</strong> " . $deployment_descriptor->ARTIFACT_ARTIFACTID . "<br/>";
  $data_content .= "<strong>Version/Timestamp:</strong> " . $deployment_descriptor->ARTIFACT_TIMESTAMP;

  return '<a href="' . $deployment_descriptor->ARTIFACT_DL_URL . '" rel="popover" data-bs-content="' . htmlspecialchars($data_content) . '" data-bs-html="true" data-bs-trigger="hover"><i class="fas fa-download"></i></a>';
}

/**
 * Return the markup for the Product Html Label
 *
 * @param $deployment_descriptor
 * @param bool $simple if true then ignore Branch Description and Instance Note if present (default: false)
 *
 * @return string html markup
*/
function componentProductHtmlLabel ($deployment_descriptor, $simple=false) {
  if (empty($deployment_descriptor->PRODUCT_DESCRIPTION)) {
      $content = htmlspecialchars($deployment_descriptor->PRODUCT_NAME);
  } else {
      $content = htmlspecialchars($deployment_descriptor->PRODUCT_DESCRIPTION);
  }
  if (!empty($deployment_descriptor->INSTANCE_ID)) {
      $content .= ' (' . htmlspecialchars($deployment_descriptor->INSTANCE_ID) . ')';
  }
  if ($simple == false) {
    if (!empty($deployment_descriptor->BRANCH_DESC)) {
        $content = '<span class="muted">'.$content.'</span>&nbsp;&nbsp;-&nbsp;&nbsp;'.htmlspecialchars($deployment_descriptor->BRANCH_DESC);
    }
    if (!empty($deployment_descriptor->INSTANCE_NOTE)) {
        $content = "<span class=\"muted\">" . $content . "</span>&nbsp;&nbsp;-&nbsp;&nbsp;" . htmlspecialchars($deployment_descriptor->INSTANCE_NOTE);
    }
  }
  return $content;
}

/**
 * Get the markup for the link(s) to open the Product url.
 *
 * @param $deployment_descriptor
 * @param string $link_text
 * @param bool $enforce_ssl
 *
 * @return string
 */
function componentProductOpenLink ($deployment_descriptor, $link_text="", $enforce_ssl=false) {
  if ($deployment_descriptor->DEPLOYMENT_APACHE_HTTPS_ENABLED) {
    $ssl=true;
  } else {
    $ssl=false;
  }
  if ($deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS) {
    $url = "http://" . $deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS;
  } else {
    $url = $deployment_descriptor->DEPLOYMENT_URL;
  }
  // Buy page deployment specificity
  if (isInstanceBuyPage($deployment_descriptor)) {
    $url.='/buy/';
  }
  $content='<a href="';
  if ($enforce_ssl && $ssl) {
    $content.=preg_replace("/http:(.*)/", "https:$1", $url);
  } else {
    $content.=$url;
  }
  $content.='" target="_blank">';
  $content.=empty($link_text) ? componentProductHtmlLabel($deployment_descriptor) : $link_text;
  $content.='</a>';

  if (! $enforce_ssl && $ssl) {
    $content.=' <a rel="tooltip" title="HTTPS link available" href="';
    $content.=preg_replace("/http:(.*)/", "https:$1", $url);
    $content.='" target="_blank">';
    $content.='<i class="fas fa-lock text-success"></i>';
    $content.='</a>';
  }
  return $content;
}

/**
 * Return the markup for the Product Version
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentProductVersion ($deployment_descriptor) {
  if (preg_match("/.*-M(LT|BL)$/", $deployment_descriptor->BASE_VERSION)) {
    $tooltipmessage=(preg_match("/.*-MBL$/", $deployment_descriptor->BASE_VERSION) ? "Before latest" : "Latest")." release (milestone, RC or GA) - continuous deployment";
    $content='<span class="text-mono" rel="tooltip" data-original-title="'.$tooltipmessage.'">'.$deployment_descriptor->ARTIFACT_TIMESTAMP.' Auto</span>';
  } else {
    $content=$deployment_descriptor->BASE_VERSION;
    $timestamp=substr_replace($deployment_descriptor->ARTIFACT_TIMESTAMP, "", 0, strlen($deployment_descriptor->BASE_VERSION));
    if (!empty($timestamp)) {
      if (!empty($deployment_descriptor->BRANCH_NAME)) {
        $content.='-'.$deployment_descriptor->BRANCH_NAME;
      }
      $content.='-SNAPSHOT';
    }
    $content='<span class="text-mono" rel="tooltip" data-original-title="'.$deployment_descriptor->ARTIFACT_TIMESTAMP.'">'.$content.'</span>';
  }
  return $content;
}

/**
 * Return the markup for the Product Html Popover
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentProductHtmlPopover($deployment_descriptor) {
  $content = '<div class="popover-content" style="min-width: 250px;">';
  $content .= '<strong>Product:</strong> ' . componentProductHtmlLabel($deployment_descriptor) . '<br>';
  $content .= '<strong>Version:</strong> ' . $deployment_descriptor->PRODUCT_VERSION . '<br>';
  $content .= '<strong>Packaging:</strong> ' . $deployment_descriptor->DEPLOYMENT_APPSRV_TYPE . ' ';
  $content .= '<i class="fas fa-server"></i><br>';
  $content .= '<strong>Database:</strong> ' . $deployment_descriptor->DATABASE . '<br>';
  $content .= '<strong>Visibility:</strong> ' . $deployment_descriptor->DEPLOYMENT_APACHE_SECURITY . ' ';
  
  if ($deployment_descriptor->DEPLOYMENT_APACHE_SECURITY === "public") {
    $content .= '<i class="fas fa-globe text-success"></i>';
  } else {
    $content .= '<i class="fas fa-lock text-warning"></i>';
  }
  
  $content .= '<br>';
  $content .= '<strong>HTTPS:</strong> ' . ($deployment_descriptor->DEPLOYMENT_APACHE_HTTPS_ENABLED ? 
    '<i class="fas fa-lock text-success"></i> yes' : 
    '<i class="fas fa-unlock text-muted"></i> no');
  
  $content .= '<br><strong>ES embedded:</strong> ' . ($deployment_descriptor->DEPLOYMENT_ES_EMBEDDED ? 
    '<i class="fas fa-check text-success"></i> yes' : 
    '<i class="fas fa-times text-danger"></i> no');
  
  $content .= '<br><strong>OnlyOffice:</strong> ' . ($deployment_descriptor->DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED ? 
    '<i class="fas fa-check text-success"></i> yes' : 
    '<i class="fas fa-times text-danger"></i> no');
  
  $content .= '<br><strong>CMIS Server:</strong> ' . ($deployment_descriptor->DEPLOYMENT_CMISSERVER_ENABLED ? 
    '<i class="fas fa-check text-success"></i> yes' : 
    '<i class="fas fa-times text-danger"></i> no');
  
  if ($deployment_descriptor->DEPLOYMENT_CHAT_ENABLED) {
    $content .= '<br><strong>Chat embedded:</strong> ' . ($deployment_descriptor->DEPLOYMENT_CHAT_EMBEDDED ? 
      '<i class="fas fa-check text-success"></i> yes' : 
      '<i class="fas fa-times text-danger"></i> no');
    $content .= '<br><strong>MongoDB:</strong> v' . $deployment_descriptor->DEPLOYMENT_CHAT_MONGODB_VERSION;
  }
  
  $content .= '<br><strong>WebSocket:</strong> ' . ((strcmp($deployment_descriptor->ACCEPTANCE_APACHE_VERSION_MINOR, '2.4') == 0 && 
    $deployment_descriptor->DEPLOYMENT_APACHE_WEBSOCKET_ENABLED) ? 
    '<i class="fas fa-check text-success"></i> yes' : 
    '<i class="fas fa-times text-danger"></i> no');
  
  $content .= '<br><strong>Virtual Host:</strong> ' . preg_replace('/https?:\/\/(.*)/', '$1', $deployment_descriptor->DEPLOYMENT_URL);
  
  if ($deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS) {
    $content .= '<br><strong>Alias:</strong> ' . $deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS;
  }
  
  if ($deployment_descriptor->DEPLOYMENT_INFO) {
    $content .= '<hr><strong>Info:</strong> ' . $deployment_descriptor->DEPLOYMENT_INFO;
  }
  
  $content .= '</div>';
  
  return $content;
}

/**
 * Get the markup for the available actions of the deployment
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentDeploymentActions($deployment_descriptor)
{
  $deploymentURL = $deployment_descriptor->DEPLOYMENT_EXT_HOST;
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_APACHE_VHOST_ALIAS') && $deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS != "") {
    $deploymentURL = $deployment_descriptor->DEPLOYMENT_APACHE_VHOST_ALIAS;
  }
  
  $content = '<div class="btn-group btn-group-sm" role="group">';
  
  // Instance logs
  $content .= '<a href="' . $deployment_descriptor->DEPLOYMENT_LOG_APPSRV_URL . '" rel="tooltip" title="Instance logs" target="_blank" class="btn btn-outline-secondary">';
  $content .= '<i class="fas fa-file-alt"></i>';
  $content .= '</a>';
  
  // Apache logs
  $content .= '<a href="' . $deployment_descriptor->DEPLOYMENT_LOG_APACHE_URL . '" rel="tooltip" title="Apache logs" target="_blank" class="btn btn-outline-secondary">';
  $content .= '<i class="fas fa-server"></i>';
  $content .= '</a>';
  
  // JMX monitoring
  if (!empty($deployment_descriptor->DEPLOYMENT_JMX_URL)) {
    $content .= '<a href="' . $deployment_descriptor->DEPLOYMENT_JMX_URL . '" rel="tooltip" title="JMX monitoring" target="_blank" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-chart-line"></i>';
    $content .= '</a>';
  }
  
  // LDAP
  if (!empty($deployment_descriptor->DEPLOYMENT_LDAP_LINK)) {
    $content .= '<a href="' . $deployment_descriptor->DEPLOYMENT_LDAP_LINK . '" rel="tooltip" title="LDAP url" target="_blank" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-address-book"></i>';
    $content .= '</a>';
  }
  
  // CRaSH SSH
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_CRASH_ENABLED') && $deployment_descriptor->DEPLOYMENT_CRASH_ENABLED) {
    $content .= '<a href="ssh://root@' . $deployment_descriptor->DEPLOYMENT_EXT_HOST . ':' . $deployment_descriptor->DEPLOYMENT_CRASH_SSH_PORT . '" rel="tooltip" title="CRaSH SSH Access" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-terminal"></i>';
    $content .= '</a>';
  }
  
  // Statistics
  $content .= '<a href="' . $deployment_descriptor->DEPLOYMENT_AWSTATS_URL . '" rel="tooltip" title="Usage statistics" target="_blank" class="btn btn-outline-secondary">';
  $content .= '<i class="fas fa-chart-bar"></i>';
  $content .= '</a>';
  
  // Elasticsearch
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_ES_ENABLED') && $deployment_descriptor->DEPLOYMENT_ES_ENABLED) {
    $content .= '<a href="http://' . $deploymentURL . '/elasticsearch" rel="tooltip" title="Elasticsearch" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-search"></i>';
    $content .= '</a>';
  }
  
  // Mailpit
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_MAILPIT_ENABLED') && $deployment_descriptor->DEPLOYMENT_MAILPIT_ENABLED) {
    $content .= '<a href="http://' . $deploymentURL . '/mailpit/" rel="tooltip" title="Mailpit" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-envelope"></i>';
    $content .= '</a>';
  }
  
  // Mongo Express
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_MONGO_EXPRESS_ENABLED') && $deployment_descriptor->DEPLOYMENT_MONGO_EXPRESS_ENABLED) {
    $content .= '<a href="http://' . $deploymentURL . '/mongoexpress/" rel="tooltip" title="Mongo Express" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-database"></i>';
    $content .= '</a>';
  }
  
  // Keycloak
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_KEYCLOAK_ENABLED') && $deployment_descriptor->DEPLOYMENT_KEYCLOAK_ENABLED) {
    $content .= '<a href="http://' . $deploymentURL . '/auth/admin/" rel="tooltip" title="Keycloak" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-key"></i>';
    $content .= '</a>';
  }
  
  // CloudBeaver
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_CLOUDBEAVER_ENABLED') && $deployment_descriptor->DEPLOYMENT_CLOUDBEAVER_ENABLED) {
    $content .= '<a href="http://' . $deploymentURL . '/cloudbeaver/" rel="tooltip" title="CloudBeaver" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-cloud"></i>';
    $content .= '</a>';
  }
  
  // phpLDAPAdmin
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_PHPLDAPADMIN_ENABLED') && $deployment_descriptor->DEPLOYMENT_PHPLDAPADMIN_ENABLED) {
    $content .= '<a href="http://' . $deploymentURL . ':' . $deployment_descriptor->DEPLOYMENT_PHPLDAPADMIN_HTTP_PORT . '" rel="tooltip" title="phpLDAPAdmin" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-address-book"></i>';
    $content .= '</a>';
  }
  
  // SFTP
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_SFTP_ENABLED') && $deployment_descriptor->DEPLOYMENT_SFTP_ENABLED) {
    $content .= '<a href="' . $deployment_descriptor->DEPLOYMENT_SFTP_LINK . '" rel="tooltip" title="SFTP" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-file-export"></i>';
    $content .= '</a>';
  }
  
  // CMIS
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_CMISSERVER_ENABLED') && $deployment_descriptor->DEPLOYMENT_CMISSERVER_ENABLED) {
    $content .= '<a href="http://' . $deployment_descriptor->DEPLOYMENT_EXT_HOST . '/cmis" rel="tooltip" title="CMIS Server" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-share-alt"></i>';
    $content .= '</a>';
  }
  
  // Baikal CalDAV
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_CALDAV_ENABLED') && $deployment_descriptor->DEPLOYMENT_CALDAV_ENABLED) {
    $content .= '<a href="http://' . $deploymentURL . '/baikal" rel="tooltip" title="CalDAV Server (Baikal)" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-calendar-alt"></i>';
    $content .= '</a>';
  }
  
  // Frontail
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_FRONTAIL_ENABLED') && $deployment_descriptor->DEPLOYMENT_FRONTAIL_ENABLED) {
    $content .= '<a href="http://' . $deploymentURL . '/livelogs/" rel="tooltip" title="Instance Live logs" target="_blank" class="btn btn-outline-secondary">';
    $content .= '<i class="fas fa-play-circle"></i>';
    $content .= '</a>';
  }
  
  $content .= '</div>';
  
  return $content;
}

/**
 * Get markup for a Feature Branch status label
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBStatusLabel($deployment_descriptor)
{
  $statusClass = match ($deployment_descriptor->ACCEPTANCE_STATE) {
    "Implementing" => "bg-info",
    "Engineering Review", "QA In Progress" => "bg-warning",
    "QA Review" => "bg-secondary",
    "QA Rejected" => "bg-danger",
    "Validated" => "bg-success",
    default => "",
  };
  return '<span class="badge ' . $statusClass . '">' . htmlspecialchars($deployment_descriptor->ACCEPTANCE_STATE) . '</span>';
}

/**
 * Get markup for a Feature Branch SCM Branch label
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBScmLabel($deployment_descriptor)
{
  if (!empty($deployment_descriptor->SCM_BRANCH)) {
    $content = '<a href="/features.php#';
    $content .= htmlspecialchars(str_replace(["/", "."], "-", $deployment_descriptor->SCM_BRANCH)) . '"';
    $content .= ' rel="tooltip" title="SCM Branch used to host this FB development">';
    $content .= '<i class="fas fa-code-branch"></i>&nbsp;' . htmlspecialchars($deployment_descriptor->SCM_BRANCH) . '</a>';
    return $content;
  }
  return '-';
}

/**
 * Get markup for a Feature Branch Issue label
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBIssueLabel($deployment_descriptor)
{
  if (!empty($deployment_descriptor->ISSUE_NUM)) {
    return '<a href="https://community.exoplatform.com/portal/dw/tasks/taskDetail/' . htmlspecialchars($deployment_descriptor->ISSUE_NUM) . '" rel="tooltip" title="Opened issue where to put your feedbacks on this new feature"><i class="fas fa-tasks"></i>&nbsp;' . htmlspecialchars($deployment_descriptor->ISSUE_NUM) . '</a>';
  }
  return '-';
}
/**
 * Get markup for a Feature Branch Edit action icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBEditIcon($deployment_descriptor)
{
  $modalId = 'edit-' . str_replace(".", "_", $deployment_descriptor->INSTANCE_KEY);
  $content = '<a role="button" data-bs-toggle="modal" data-bs-target="#' . $modalId . '" title="Edit feature branch"><i class="fas fa-pencil-alt"></i></a>';
  $content .= getFormEditFeatureBranch($deployment_descriptor);
  return $content;
}

/**
 * Get markup for a Feature Branch Deploy action icon
 *
 * @param $deployment_descriptor
 *
 * @return string html markup
 */
function componentFBDeployIcon($deployment_descriptor)
{
  if (isset($deployment_descriptor->DEPLOYMENT_BUILD_URL)) {
    return '<a href="' . $deployment_descriptor->DEPLOYMENT_BUILD_URL . '/build?delay=0sec" rel="tooltip" title="Restart your instance or reset your instance data" target="_blank"><i class="fas fa-sync-alt"></i></a>';
  }
  return '';
}

/**
 * Get markup for a Git repository branch commits status
 *
 * @param $fb_project
 * @param $cherry_commits_display
 *
 * @return string html markup
 */
function componentFeatureRepoBrancheStatus($fb_project, $cherry_commits_display = false)
{
  if ($cherry_commits_display) {
    if ($fb_project['cherry_commits'] > 0) {
      return '<span class="commit-stat behind" rel="tooltip" title="Some commits on the base branch that do not exist on this branch">
                <i class="fas fa-arrow-down"></i> ' . $fb_project['cherry_commits'] . '
              </span>';
    } else {
      return '<span class="commit-stat" rel="tooltip" title="Up to date">
                <i class="fas fa-check"></i>
              </span>';
    }
  }

  $content = '<div class="commit-stats">';
  
  // Behind
  $content .= '<a href="' . $fb_project['http_url_behind'] . '" target="_blank" class="commit-stat ' . ($fb_project['behind_commits'] > 0 ? 'behind' : '') . '" rel="tooltip" title="' . $fb_project['behind_commits'] . ' commits behind base branch">';
  $content .= '<i class="fas fa-arrow-down"></i> ' . $fb_project['behind_commits'];
  $content .= '</a>';
  
  // Ahead
  $content .= '<a href="' . $fb_project['http_url_ahead'] . '" target="_blank" class="commit-stat ' . ($fb_project['ahead_commits'] > 0 ? 'ahead' : '') . '" rel="tooltip" title="' . $fb_project['ahead_commits'] . ' commits ahead of base branch">';
  $content .= '<i class="fas fa-arrow-up"></i> ' . $fb_project['ahead_commits'];
  $content .= '</a>';
  
  $content .= '</div>';

  return $content;
}

/**
 * Get markup for the "restart or reset data" build-trigger link shown on
 * instance cards, using the descriptor's own DEPLOYMENT_BUILD_URL when
 * available or a caller-supplied fallback Jenkins job URL otherwise.
 *
 * @param $deployment_descriptor
 * @param string $fallback_url the CI job URL to use when DEPLOYMENT_BUILD_URL isn't set
 *
 * @return string html markup
 */
function componentBuildRestartLink($deployment_descriptor, $fallback_url)
{
  $url = isset($deployment_descriptor->DEPLOYMENT_BUILD_URL)
    ? $deployment_descriptor->DEPLOYMENT_BUILD_URL . '/build?delay=0sec'
    : $fallback_url;
  return '<a href="' . htmlspecialchars($url) . '" target="_blank" rel="tooltip" title="Restart or reset data"><i class="fas fa-sync-alt"></i></a>';
}

/**
 * Render a single instance card.
 *
 * This is the one shared implementation of the `.instance-card` markup used
 * by index.php, sales.php, company.php, customers.php and qa.php, which each
 * show a slightly different subset of badges/actions for their audience.
 * Pass only the $opts a given listing needs; unset ones fall back to the
 * most common shape (used by sales.php/customers.php/qa.php).
 *
 * @param $inst a deployment descriptor
 * @param array $opts {
 *   @var bool         $rich_name           name shows visibility+app-server icon inside the product link (index.php style)
 *   @var bool         $info_icon           show the product info popover icon (ignored when $rich_name is true)
 *   @var string|false $visibility_icon     color to pass to componentVisibilityIcon(), or false to hide it (ignored when $rich_name is true)
 *   @var string       $link_text           link text override for componentProductOpenLink() (ignored when $rich_name is true)
 *   @var bool         $enforce_ssl         enforce SSL on the product link (ignored when $rich_name is true)
 *   @var bool         $meta_download_first show the download icon before the version instead of after
 *   @var string       $actions_top         pre-rendered html for the top-right action icons
 *   @var bool         $show_built_age      also show the "built X ago" age (in addition to "deployed X ago")
 *   @var bool         $feature_label       show the FB SCM branch label (only when the instance is a feature branch)
 *   @var bool         $fb_badges           show the FB status/issue/edit/deploy badge row (only when the instance is a feature branch)
 *   @var string[]     $badges              ordered subset of: upgrade, patch, certbot, dev, staging, debug, addons
 *   @var bool         $badges_addon_style  badge-pill style (true) vs. bare tooltipped icon style (false) for $badges
 *   @var bool         $labels              show componentLabels()
 *   @var bool         $actions             show the componentDeploymentActions() button group
 * }
 *
 * @return string html markup
 */
function renderInstanceCard($inst, array $opts = [])
{
  $opts += [
    'rich_name' => false,
    'info_icon' => true,
    'visibility_icon' => false,
    'link_text' => '',
    'enforce_ssl' => false,
    'meta_download_first' => false,
    'actions_top' => '',
    'show_built_age' => false,
    'feature_label' => false,
    'fb_badges' => false,
    'badges' => ['upgrade', 'patch', 'certbot', 'dev', 'staging', 'debug', 'addons'],
    'badges_addon_style' => true,
    'labels' => false,
    'actions' => true,
  ];

  $badgeMarkup = '';
  foreach ($opts['badges'] as $badge) {
    $badgeMarkup .= match ($badge) {
      'upgrade' => componentUpgradeEligibility($inst, $opts['badges_addon_style']),
      'patch' => componentPatchInstallation($inst, $opts['badges_addon_style']),
      'certbot' => componentCertbotEnabled($inst, $opts['badges_addon_style']),
      'dev' => componentDevModeEnabled($inst, $opts['badges_addon_style']),
      'staging' => componentStagingModeEnabled($inst, $opts['badges_addon_style']),
      'debug' => componentDebugModeEnabled($inst, $opts['badges_addon_style']),
      'addons' => componentAddonsTags($inst),
      default => '',
    };
  }
  if ($opts['labels']) {
    $badgeMarkup .= componentLabels($inst);
  }

  $isFeatureBranch = isInstanceFeatureBranch($inst);

  ob_start();
?>
<div class="instance-card">
    <div class="instance-card__top">
        <div class="instance-card__status">
            <?php if ($inst->DEPLOYMENT_STATUS == "Up"): ?>
                <span class="pulse-dot on" title="Running" aria-label="Status: Up"></span>
            <?php else: ?>
                <span class="pulse-dot off" title="Stopped" aria-label="Status: Down"></span>
            <?php endif; ?>
        </div>
        <div class="instance-card__info">
            <div class="instance-card__name">
                <?php if ($opts['rich_name']): ?>
                    <?= componentProductInfoIcon($inst) ?>
                    <?php
                    $label = componentVisibilityIcon($inst, empty($inst->DEPLOYMENT_APACHE_VHOST_ALIAS) ? '' : 'success');
                    $label .= ' ' . componentAppServerIcon($inst);
                    $label .= ' ' . componentProductHtmlLabel($inst);
                    echo componentProductOpenLink($inst, $label);
                    ?>
                <?php else: ?>
                    <?php if ($opts['info_icon']): ?><?= componentProductInfoIcon($inst) ?><?php endif; ?>
                    <?php if ($opts['visibility_icon'] !== false): ?><?= componentVisibilityIcon($inst, $opts['visibility_icon']) ?><?php endif; ?>
                    <?= componentProductOpenLink($inst, $opts['link_text'], $opts['enforce_ssl']) ?>
                <?php endif; ?>
            </div>
            <div class="instance-card__meta">
                <?php if ($opts['meta_download_first']): ?>
                    <?= componentDownloadIcon($inst) ?>
                    <?= componentProductVersion($inst) ?>
                <?php else: ?>
                    <?= componentProductVersion($inst) ?>
                    <?= componentDownloadIcon($inst) ?>
                <?php endif; ?>
            </div>
        </div>
        <div class="instance-card__actions-top">
            <?= $opts['actions_top'] ?>
        </div>
    </div>
    <div class="instance-card__details">
        <?= componentDatabaseIcon($inst) ?>
        <?php if ($opts['feature_label'] && $isFeatureBranch): ?>
            <span class="instance-card__feature"><?= componentFBScmLabel($inst) ?></span>
        <?php endif; ?>
        <div class="instance-card__ages">
            <?php if ($opts['show_built_age']): ?>
            <span class="<?= $inst->ARTIFACT_AGE_CLASS ?>" title="Time since artifact was built"><i class="fas fa-calendar-alt me-1"></i>built <?= $inst->ARTIFACT_AGE_STRING ?></span>
            <?php endif; ?>
            <span title="Time since instance was deployed"><i class="fas fa-clock me-1"></i>deployed <?= $inst->DEPLOYMENT_AGE_STRING ?></span>
        </div>
    </div>
    <?php if ($opts['fb_badges'] && $isFeatureBranch): ?>
    <div class="instance-card__badges">
        <?= componentFBStatusLabel($inst) ?>
        <?= componentFBIssueLabel($inst) ?>
        <?= componentFBEditIcon($inst) ?>
        <?= componentFBDeployIcon($inst) ?>
    </div>
    <?php endif; ?>
    <?php if ($badgeMarkup !== ''): ?>
    <div class="instance-card__badges">
        <?= $badgeMarkup ?>
    </div>
    <?php endif; ?>
    <?php if ($opts['actions']): ?>
    <div class="instance-card__actions">
        <?= componentDeploymentActions($inst) ?>
    </div>
    <?php endif; ?>
</div>
<?php
  return ob_get_clean();
}

/**
 * Render the JMX / Keycloak / LDAP access-info card row shared by the
 * dashboard and every instance-listing page (index.php, sales.php,
 * company.php, customers.php, qa.php).
 *
 * @return string html markup
 */
function componentAccessInfoCards()
{
  $items = [
    [
      'id' => 'accessInfoJmx',
      'icon' => 'fas fa-plug',
      'title' => 'JMX Access',
      'body' => '<p class="card-text">Each instance can be accessed using JMX with the URL linked to the monitoring icon. Credentials can be found on CI Build.</p>',
    ],
    [
      'id' => 'accessInfoKeycloak',
      'icon' => 'fas fa-key',
      'title' => 'Keycloak Access',
      'body' => '<p class="card-text">Each deployed Keycloak can be accessed using the Keycloak icon with credentials:</p>
                <div class="mt-2 p-2 rounded code-bg">
                    <code class="d-block">root / password</code>
                </div>',
    ],
    [
      'id' => 'accessInfoLdap',
      'icon' => 'fas fa-address-book',
      'title' => 'LDAP Access',
      'body' => '<p class="card-text">Each LDAP deployed can be accessed with:</p>
                <div class="mt-2 p-2 rounded code-bg">
                    <code class="d-block">Base DN: dc=exoplatform,dc=com</code>
                    <code class="d-block mt-1">User DN: cn=admin,dc=exoplatform,dc=com</code>
                    <code class="d-block mt-1">password: exo</code>
                </div>',
    ],
  ];

  ob_start();
?>
<!-- Desktop: 3 always-expanded cards. Mobile: collapsible accordion (same
     markup, styled/behaved differently per breakpoint — see .access-info-*
     rules in style.css) so the static reference text doesn't eat a full
     screen of scroll before real page content on small viewports. -->
<div class="access-info-grid mt-4">
    <?php foreach ($items as $item): ?>
    <div class="access-info-item card h-100">
        <button type="button" class="access-info-toggle card-header" data-bs-toggle="collapse" data-bs-target="#<?= $item['id'] ?>" aria-expanded="false" aria-controls="<?= $item['id'] ?>">
            <i class="<?= $item['icon'] ?> me-2"></i><?= htmlspecialchars($item['title']) ?>
            <i class="fas fa-chevron-down access-info-chevron" aria-hidden="true"></i>
        </button>
        <div class="collapse access-info-body" id="<?= $item['id'] ?>">
            <div class="card-body">
                <?= $item['body'] ?>
            </div>
        </div>
    </div>
    <?php endforeach; ?>
</div>
<?php
  return ob_get_clean();
}

/**
 * Render the "Debug Menu" navigation card shared by debug.php, debug-caches.php,
 * debug-deploy.php and debug-git.php.
 *
 * @return string html markup
 */
function componentDebugMenu()
{
  ob_start();
?>
<div class="card mb-4">
    <div class="card-header"><i class="fas fa-bug me-2"></i>Debug Menu</div>
    <div class="card-body">
        <ul class="list-group">
            <li class="list-group-item">
                <i class="fas fa-code-branch me-2 text-primary"></i>
                <a href="/debug-git.php">Debug Git functions</a>
            </li>
            <li class="list-group-item">
                <i class="fas fa-rocket me-2 text-success"></i>
                <a href="/debug-deploy.php">Debug Deployment</a>
            </li>
            <li class="list-group-item">
                <i class="fas fa-database me-2 text-warning"></i>
                <a href="/debug-caches.php">Debug Caches</a>
                (<a href="/debug-caches.php?clearCaches=true" class="text-danger">Clear all Caches</a>)
            </li>
        </ul>
    </div>
</div>
<?php
  return ob_get_clean();
}
?>