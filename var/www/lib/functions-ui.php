<?php
require_once(dirname(__FILE__) . '/functions-ui-form-edit-fb.php');
require_once(dirname(__FILE__) . '/functions-ui-form-edit-note.php');

/**
 * Insert the page header lines
 *
 * @param string $title the title of the page (default: none)
 */
function pageHeader($title = "")
{
?>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <meta http-equiv="refresh" content="120">
  <title>Acceptance<?= (empty($title) ? "" : " - " . $title) ?></title>
  <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
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
    var THEMES = ['default', 'ocean', 'forest', 'twilight'];
    var THEME_LABELS = { 'default': 'Default', 'ocean': 'Ocean', 'forest': 'Forest', 'twilight': 'Twilight' };

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
      if (btn) btn.textContent = THEME_LABELS[accent] || accent;
    }

    // ── Full apply: scheme + accent + UI + persist ───────
    function applyTheme(accent, scheme, persist) {
      setAccent(accent);
      document.documentElement.setAttribute('data-bs-theme', scheme);
      if (persist) storeTheme(accent, scheme);

      // Update toggle button
      var toggleBtn = document.getElementById('darkModeToggle');
      if (toggleBtn) {
        var isDark = scheme === 'dark';
        var icon = toggleBtn.querySelector('i');
        var srSpan = toggleBtn.querySelector('.sr-only');
        var label = isDark ? 'Switch to light mode' : 'Switch to dark mode';
        if (icon) icon.className = isDark ? 'fas fa-sun' : 'fas fa-moon';
        toggleBtn.setAttribute('title', label);
        toggleBtn.setAttribute('aria-label', label);
        toggleBtn.setAttribute('aria-pressed', isDark ? 'true' : 'false');
        if (srSpan) srSpan.textContent = label;
        var tip = bootstrap.Tooltip.getInstance(toggleBtn);
        if (tip) tip.dispose();
        new bootstrap.Tooltip(toggleBtn);
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
 * Insert the navigation bar
 */
function pageNavigation()
{
  $nav = array(
    "Home" => "/",
    "QA" => "/qa.php",
    "Sales" => "/sales.php",
    "CP" => "/customers.php",
    "Company" => "/company.php",
    "Features" => "/features.php",
    "Servers" => "/servers.php"
  );
  
?>
  <!-- Skip to main content link -->
  <a href="#main" class="skip-to-content sr-only-focusable">
    <i class="fas fa-arrow-down me-1" aria-hidden="true"></i>Skip to main content
  </a>
  <!-- navbar ================================================== -->
  <nav class="navbar navbar-expand-lg navbar-dark fixed-top" aria-label="Main navigation">
    <div class="container-fluid">
      <a class="navbar-brand" href="/" aria-label="Home page">
        <i class="fas fa-cloud me-2" aria-hidden="true"></i><?= $_SERVER['SERVER_NAME'] ?>
      </a>
      <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>
      <div class="collapse navbar-collapse" id="navbarNav">
        <ul class="navbar-nav" role="list">
          <?php
          foreach ($nav as $label => $url) {
            $active = ($url == $_SERVER['REQUEST_URI']) ? 'active' : '';
            $ariaCurrent = ($url == $_SERVER['REQUEST_URI']) ? ' aria-current="page"' : '';
            echo '<li class="nav-item"><a class="nav-link ' . $active . '" href="' . $url . '"' . $ariaCurrent . '>' . $label . '</a></li>';
          }
          ?>
        </ul>
        
        <!-- Theme picker + dark mode toggle -->
        <ul class="navbar-nav ms-auto align-items-center" role="list">
          <!-- Theme accent dropdown -->
          <li class="nav-item dropdown">
            <button class="nav-link dropdown-toggle" id="themeDropdown" data-bs-toggle="dropdown" aria-expanded="false" aria-label="Select theme">
              Default
            </button>
            <ul class="dropdown-menu dropdown-menu-end" id="themeDropdownMenu" aria-labelledby="themeDropdown">
              <li><button class="dropdown-item" onclick="pickTheme('default')">Default</button></li>
              <li><button class="dropdown-item" onclick="pickTheme('ocean')">Ocean</button></li>
              <li><button class="dropdown-item" onclick="pickTheme('forest')">Forest</button></li>
              <li><button class="dropdown-item" onclick="pickTheme('twilight')">Twilight</button></li>
            </ul>
          </li>
          <!-- Light/dark toggle -->
          <li class="nav-item">
            <button class="nav-link" id="darkModeToggle" onclick="toggleScheme()" title="Switch to dark mode" aria-label="Switch to dark mode" aria-pressed="false">
              <i class="fas fa-moon" aria-hidden="true"></i>
              <span class="sr-only">Switch to dark mode</span>
            </button>
            <script>
              (function() {
                var a = document.documentElement.getAttribute('data-accent') || 'default';
                var s = document.documentElement.getAttribute('data-bs-theme') || 'light';
                var isDark = s === 'dark';
                var btn = document.getElementById('darkModeToggle');
                if (btn) {
                  btn.querySelector('i').className = isDark ? 'fas fa-sun' : 'fas fa-moon';
                  var label = isDark ? 'Switch to light mode' : 'Switch to dark mode';
                  btn.setAttribute('title', label);
                  btn.setAttribute('aria-label', label);
                  btn.setAttribute('aria-pressed', isDark ? 'true' : 'false');
                  var sr = btn.querySelector('.sr-only');
                  if (sr) sr.textContent = label;
                }
                var td = document.getElementById('themeDropdown');
                if (td) td.textContent = ({'default':'Default','ocean':'Ocean','forest':'Forest','twilight':'Twilight'}[a]) || a;
              })();
            </script>
          </li>
        </ul>
      </div>
    </div>
  </nav>
  <!-- /navbar -->
<?php
}


/**
 * Insert the Footer
 */
function pageFooter() {
?>
  <!-- Footer ================================================== -->
  <footer id="footer" class="footer" role="contentinfo">
    <div class="container-fluid">
      <div class="row">
        <div class="col">
          <span class="sr-only">Copyright</span> Copyright &copy; 2006-<?= date("Y") ?>. All rights Reserved, eXo Platform SAS
          <a href="/stats/awstats.pl?config=<?= $_SERVER['SERVER_NAME'] ?>" class="ms-3" target="_blank" aria-label="View statistics">
            <i class="fas fa-chart-bar" aria-hidden="true"></i>
          </a>
        </div>
      </div>
    </div>
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
      $content.='<span class="label label-label">'.$label.'</span>&nbsp;';
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
      $content .= '<span class="badge bg-info" rel="tooltip" title="version: ' . $version . '">' . $label_array[0] . '</span> ';
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
  return '<span class="badge bg-secondary" rel="tooltip" title="distribution add-ons: ' . $deployment_descriptor->PRODUCT_ADDONS_DISTRIB . '"><i class="fas fa-gift"></i></span>';
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
  if (property_exists($deployment_descriptor, 'INSTANCE_TOKEN') && $deployment_descriptor->INSTANCE_TOKEN) {
    if (!$is_label_addon) {
      return '<span rel="tooltip" data-original-title="This instance is eligible for upgrades."><i class="fas fa-flag"></i></span>';
    } else {
      return '<span class="badge bg-info" rel="tooltip" title="This instance is eligible for upgrades."><i class="fas fa-flag"></i></span>';
    }
  }
  return '';
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
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_PATCHES') && $deployment_descriptor->DEPLOYMENT_PATCHES) {
    if (!$is_label_addon) {
      return '<span rel="tooltip" title="' . $deployment_descriptor->DEPLOYMENT_PATCHES . ' is installed on this instance."><i class="fas fa-plus-circle"></i></span>';
    } else {
      return '<span class="badge bg-success" rel="tooltip" title="' . $deployment_descriptor->DEPLOYMENT_PATCHES . ' is installed on this instance."><i class="fas fa-plus-circle"></i></span>';
    }
  }
  return '';
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
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_STAGING_ENABLED') && $deployment_descriptor->DEPLOYMENT_STAGING_ENABLED) {
    if (!$is_label_addon) {
      return '<span rel="tooltip" title="This instance is enabled with Staging mode."><i class="fas fa-fire"></i></span>';
    } else {
      return '<span class="badge bg-warning" rel="tooltip" title="This instance is enabled with Staging mode."><i class="fas fa-fire"></i></span>';
    }
  }
  return '';
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
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_DEV_ENABLED') && $deployment_descriptor->DEPLOYMENT_DEV_ENABLED) {
    if (!$is_label_addon) {
      return '<span rel="tooltip" title="This instance is enabled with Dev mode."><i class="fab fa-github"></i></span>';
    } else {
      return '<span class="badge bg-dark" rel="tooltip" title="This instance is enabled with Dev mode."><i class="fab fa-github"></i></span>';
    }
  }
  return '';
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
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_DEBUG_ENABLED') && $deployment_descriptor->DEPLOYMENT_DEBUG_ENABLED) {
    if (!$is_label_addon) {
      return '<span rel="tooltip" title="This instance is enabled with Debug mode."><i class="fas fa-stethoscope"></i></span>';
    } else {
      return '<span class="badge bg-danger" rel="tooltip" title="This instance is enabled with Debug mode."><i class="fas fa-stethoscope"></i></span>';
    }
  }
  return '';
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
  if (property_exists($deployment_descriptor, 'DEPLOYMENT_CERTBOT_ENABLED') && $deployment_descriptor->DEPLOYMENT_CERTBOT_ENABLED) {
    if (!$is_label_addon) {
      return '<span rel="tooltip" title="This instance SSL certificate is generated by certbot."><i class="fas fa-certificate"></i></span>';
    } else {
      return '<span class="badge bg-primary" rel="tooltip" title="This instance SSL certificate is generated by certbot."><i class="fas fa-certificate"></i></span>';
    }
  }
  return '';
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
  $icons = array(
    'tomcat' => 'fa-brands fa-java',
    'jboss' => 'fa-brands fa-redhat',
    'wildfly' => 'fa-brands fa-redhat'
  );
  
  $type = strtolower($deployment_descriptor->DEPLOYMENT_APPSRV_TYPE);
  $icon = isset($icons[$type]) ? $icons[$type] : 'fa-server';
  
  return '<i class="fas ' . $icon . '" rel="tooltip" title="Application Server: ' . $deployment_descriptor->DEPLOYMENT_APPSRV_TYPE . '"></i>';
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
  $content = '<a href="#" rel="tooltip" title="Add/Edit Instance Note" data-bs-toggle="modal" data-bs-target="#' . $modalId . '"><i class="fas fa-pencil-alt"></i></a>';
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
    return '<a rel="tooltip" title="Specifications link" href="' . $deployment_descriptor->SPECIFICATIONS_LINK . '" target="_blank"><i class="fas fa-book"></i></a>';
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
  $db_type = "none";
  $icon_class = "fa-database";
  $icon_color = "text-secondary";
  
  if (stripos($deployment_descriptor->DATABASE, 'mysql') !== false) {
    $db_type = "MySQL";
    $icon_class = "fa-database";
    $icon_color = "text-primary";
  } else if (stripos($deployment_descriptor->DATABASE, 'mariadb') !== false) {
    $db_type = "MariaDB";
    $icon_class = "fa-database";
    $icon_color = "text-success";
  } else if (stripos($deployment_descriptor->DATABASE, 'postgres') !== false) {
    $db_type = "PostgreSQL";
    $icon_class = "fa-database";
    $icon_color = "text-info";
  } else if (stripos($deployment_descriptor->DATABASE, 'oracle') !== false) {
    $db_type = "Oracle";
    $icon_class = "fa-database";
    $icon_color = "text-danger";
  } else if (stripos($deployment_descriptor->DATABASE, 'sqlserver') !== false) {
    $db_type = "SQL Server";
    $icon_class = "fa-database";
    $icon_color = "text-warning";
  } else if (stripos($deployment_descriptor->DATABASE, 'h2') !== false) {
    $db_type = "H2";
    $icon_class = "fa-database";
    $icon_color = "text-secondary";
  } else if (stripos($deployment_descriptor->DATABASE, 'hsql') !== false) {
    $db_type = "HSQLDB";
    $icon_class = "fa-database";
    $icon_color = "text-secondary";
  }
  
  $content = "";
  if ($db_type != "none") {
    $content .= '<i class="fas ' . $icon_class . ' ' . $icon_color . '" rel="tooltip" title="' . $db_type . '"></i>&nbsp;';
  } else {
    $content .= '<i class="fas fa-database text-muted" rel="tooltip" title="No database"></i>&nbsp;';
  }
  
  if (empty($deployment_descriptor->DEPLOYMENT_DATABASE_VERSION)) {
    $content .= '<span class="badge bg-secondary">-NC-</span>';
  } else {
    $content .= '<span class="badge bg-info">' . $deployment_descriptor->DEPLOYMENT_DATABASE_VERSION . '</span>';
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
      $content = $deployment_descriptor->PRODUCT_NAME;
  } else {
      $content = $deployment_descriptor->PRODUCT_DESCRIPTION;
  }
  if (!empty($deployment_descriptor->INSTANCE_ID)) {
      $content .= ' (' . $deployment_descriptor->INSTANCE_ID . ')';
  }
  if ($simple == false) {
    if (!empty($deployment_descriptor->BRANCH_DESC)) {
        $content = '<span class="muted">'.$content.'</span>&nbsp;&nbsp;-&nbsp;&nbsp;'.$deployment_descriptor->BRANCH_DESC;
    }
    if (!empty($deployment_descriptor->INSTANCE_NOTE)) {
        $content = "<span class=\"muted\">" . $content . "</span>&nbsp;&nbsp;-&nbsp;&nbsp;" . $deployment_descriptor->INSTANCE_NOTE;
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
    $tooltipmessage=(preg_match("/.*-MBL$/", $deployment_descriptor->BASE_VERSION) ? "Before latest" : "Latest")." milestone continuous deployment enabled";
    $content=$deployment_descriptor->ARTIFACT_TIMESTAMP.' <span style="font-size: small" class="muted" rel="tooltip" data-original-title="'.$tooltipmessage.'">Auto</span>';
  } else {
    $content=$deployment_descriptor->BASE_VERSION;
    $timestamp=substr_replace($deployment_descriptor->ARTIFACT_TIMESTAMP, "", 0, strlen($deployment_descriptor->BASE_VERSION));
    if (!empty($timestamp)) {
      $content.='<span style="font-size: small" class="muted" rel="tooltip" data-original-title="'.$deployment_descriptor->ARTIFACT_TIMESTAMP.'">';
      if (!empty($deployment_descriptor->BRANCH_NAME)) {
        $content.='-'.$deployment_descriptor->BRANCH_NAME;
      }
      $content.='-SNAPSHOT</span>';
    }
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
  $statusClass = "";
  if ($deployment_descriptor->ACCEPTANCE_STATE === "Implementing") {
    $statusClass = "bg-info";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "Engineering Review") {
    $statusClass = "bg-warning";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "QA Review") {
    $statusClass = "bg-secondary";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "QA In Progress") {
    $statusClass = "bg-warning";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "QA Rejected") {
    $statusClass = "bg-danger";
  } else if ($deployment_descriptor->ACCEPTANCE_STATE === "Validated") {
    $statusClass = "bg-success";
  }
  return '<span class="badge ' . $statusClass . '">' . $deployment_descriptor->ACCEPTANCE_STATE . '</span>';
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
    $content .= str_replace(array("/", "."), "-", $deployment_descriptor->SCM_BRANCH) . '"';
    $content .= ' rel="tooltip" title="SCM Branch used to host this FB development">';
    $content .= '<i class="fas fa-code-branch"></i>&nbsp;' . $deployment_descriptor->SCM_BRANCH . '</a>';
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
    return '<a href="https://community.exoplatform.com/portal/dw/tasks/taskDetail/' . $deployment_descriptor->ISSUE_NUM . '" rel="tooltip" title="Opened issue where to put your feedbacks on this new feature"><i class="fas fa-tasks"></i>&nbsp;' . $deployment_descriptor->ISSUE_NUM . '</a>';
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
  $content = '<a href="#" rel="tooltip" title="Edit feature branch details" data-bs-toggle="modal" data-bs-target="#' . $modalId . '"><i class="fas fa-pencil-alt"></i></a>';
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
?>