<?php
require_once(dirname(__FILE__) . '/functions-ui-form-edit-fb.php');
require_once(dirname(__FILE__) . '/functions-ui-form-edit-note.php');

/**
 * Insert the page header lines
 */
function pageHeader($title = "")
{
?>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="refresh" content="120">
  <title>Acceptance<?= (empty($title) ? "" : " — " . $title) ?></title>
  <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
  <!-- Google Fonts: IBM Plex Sans + IBM Plex Mono -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:ital,wght@0,400;0,500;0,600;1,400&family=IBM+Plex+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;1,400&display=swap" rel="stylesheet">
  <!-- Bootstrap 5 -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <!-- Font Awesome 6 -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
  <!-- Custom CSS -->
  <link href="./style.css" media="screen" rel="stylesheet" type="text/css" />
  <!-- jQuery -->
  <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
  <!-- Bootstrap JS -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
  <!-- Theme init (runs before render to prevent flash) -->
  <script>
    (function() {
      var saved = localStorage.getItem('adt-theme');
      var prefer = (!saved && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) ? 'dark' : (saved || 'dark');
      document.documentElement.setAttribute('data-bs-theme', prefer);
    })();
    function adtToggleTheme() {
      var cur = document.documentElement.getAttribute('data-bs-theme') || 'dark';
      var next = cur === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-bs-theme', next);
      localStorage.setItem('adt-theme', next);
      var btn = document.getElementById('themeToggle');
      if (btn) btn.querySelector('i').className = next === 'dark' ? 'fas fa-sun' : 'fas fa-moon';
    }
  </script>
<?php
}

/**
 * Insert the Google Analytics tracking script
 */
function pageTracker($id = 'UA-1292368-28') {
?>
  <script>
    (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
    (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
    m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
    })(window,document,'script','https://www.google-analytics.com/analytics.js','ga');
    ga('create','<?= $id ?>','auto');
    ga('send','pageview');
  </script>
<?php
}

/**
 * Build the navigation items array
 */
function getNavItems() {
  return [
    ['label' => 'Instances', 'url' => '/',            'icon' => 'fa-server'],
    ['label' => 'QA',        'url' => '/qa.php',       'icon' => 'fa-flask'],
    ['label' => 'Sales',     'url' => '/sales.php',    'icon' => 'fa-chart-line'],
    ['label' => 'CP',        'url' => '/customers.php','icon' => 'fa-users'],
    ['label' => 'Company',   'url' => '/company.php',  'icon' => 'fa-building'],
    ['label' => 'Features',  'url' => '/features.php', 'icon' => 'fa-code-branch'],
    ['label' => 'Servers',   'url' => '/servers.php',  'icon' => 'fa-database'],
  ];
}

/**
 * Insert the full page shell: sidebar + topbar wrapper.
 * Call this instead of the old pageNavigation().
 * Pages should wrap their content in .adt-content themselves via pageOpenContent() / pageCloseContent().
 */
function pageNavigation() {
  $nav   = getNavItems();
  $uri   = $_SERVER['REQUEST_URI'];
  $host  = $_SERVER['SERVER_NAME'];
  $isDark = isset($_COOKIE['adt-theme']) ? ($_COOKIE['adt-theme'] === 'dark') : true;
  $themeIcon = $isDark ? 'fa-sun' : 'fa-moon';
?>
<!-- ═══ ADT SHELL ═══ -->
<div class="adt-shell">

  <!-- SIDEBAR -->
  <aside class="adt-sidebar">
    <!-- Logo -->
    <div class="sidebar-logo">
      <div class="logo-mark">
        <div class="logo-icon">ADT</div>
        <div>
          <div class="logo-text">Acceptance</div>
        </div>
      </div>
      <div class="logo-host"><?= htmlspecialchars($host) ?></div>
    </div>

    <!-- Environments section -->
    <div class="sidebar-section">
      <div class="sidebar-section-title">Environments</div>
      <?php foreach ($nav as $item):
        $active = ($item['url'] === $uri || ($item['url'] !== '/' && strpos($uri, $item['url']) === 0)) ? 'active' : '';
      ?>
      <a class="nav-item <?= $active ?>" href="<?= $item['url'] ?>" data-label="<?= $item['label'] ?>">
        <span class="nav-icon"><i class="fas <?= $item['icon'] ?>"></i></span>
        <?= $item['label'] ?>
      </a>
      <?php endforeach; ?>
    </div>

    <!-- Status summary -->
    <div class="sidebar-status">
      <div class="status-title">Live status</div>
      <div class="status-row">
        <span class="status-label">Online</span>
        <span id="sb-online" class="s-green">—</span>
      </div>
      <div class="status-row">
        <span class="status-label">Down</span>
        <span id="sb-down" class="s-red">—</span>
      </div>
      <div class="status-row">
        <span class="status-label">Instances</span>
        <span id="sb-total" class="s-blue">—</span>
      </div>
    </div>
  </aside>

  <!-- MAIN PANEL -->
  <div class="adt-main">

    <!-- TOPBAR -->
    <div class="adt-topbar">
      <div class="topbar-breadcrumb">
        <span class="crumb">ADT</span>
        <span class="crumb-sep">/</span>
        <?php foreach ($nav as $item):
          $active = ($item['url'] === $uri || ($item['url'] !== '/' && strpos($uri, $item['url']) === 0));
          if ($active): ?>
            <span class="crumb-active"><?= $item['label'] ?></span>
          <?php endif;
        endforeach; ?>
      </div>
      <div class="topbar-right">
        <div class="live-indicator">
          <span class="live-dot"></span>auto-refresh 2m
        </div>
        <button class="topbar-btn" id="themeToggle" onclick="adtToggleTheme()" title="Toggle theme">
          <i class="fas <?= $themeIcon ?>"></i>
        </button>
        <button class="topbar-btn mobile-menu-btn" id="mobileMenuBtn" onclick="adtToggleMobileMenu()" title="Menu" aria-label="Open navigation menu">
          <i class="fas fa-bars"></i>
        </button>
      </div>
    </div>

    <!-- MOBILE DRAWER OVERLAY -->
    <div class="mobile-drawer-overlay" id="mobileDrawerOverlay" onclick="adtCloseMobileMenu()"></div>

    <!-- MOBILE DRAWER PANEL -->
    <div class="mobile-drawer" id="mobileDrawer">
      <div class="mobile-drawer-header">
        <div class="logo-mark">
          <div class="logo-icon">ADT</div>
          <div>
            <div class="logo-text">Acceptance</div>
            <div class="logo-host"><?= htmlspecialchars($host) ?></div>
          </div>
        </div>
        <button class="mobile-drawer-close" onclick="adtCloseMobileMenu()" aria-label="Close menu">
          <i class="fas fa-times"></i>
        </button>
      </div>
      <div class="mobile-drawer-nav">
        <?php foreach ($nav as $item):
          $active = ($item['url'] === $uri || ($item['url'] !== '/' && strpos($uri, $item['url']) === 0)) ? 'active' : '';
        ?>
        <a class="mobile-drawer-item <?= $active ?>" href="<?= $item['url'] ?>">
          <span class="mobile-drawer-icon"><i class="fas <?= $item['icon'] ?>"></i></span>
          <?= $item['label'] ?>
        </a>
        <?php endforeach; ?>
      </div>
    </div>

    <!-- PAGE CONTENT goes here -->
    <div class="adt-content">
<?php
}

/**
 * Insert the page footer and close the shell.
 */
function pageFooter() {
?>
    </div><!-- /.adt-content -->

    <!-- FOOTER -->
    <footer id="footer">
      Copyright &copy; 2006-<?= date("Y") ?>. All rights Reserved, eXo Platform SAS
      <a href="/stats/awstats.pl?config=<?= $_SERVER['SERVER_NAME'] ?>" class="ms-3" target="_blank">
        <i class="fas fa-chart-bar"></i>
      </a>
    </footer>

  </div><!-- /.adt-main -->



</div><!-- /.adt-shell -->

<script>
// Mobile drawer
function adtToggleMobileMenu() {
  var drawer = document.getElementById('mobileDrawer');
  var overlay = document.getElementById('mobileDrawerOverlay');
  var isOpen = drawer.classList.contains('open');
  if (isOpen) {
    drawer.classList.remove('open');
    overlay.classList.remove('open');
    document.body.style.overflow = '';
  } else {
    drawer.classList.add('open');
    overlay.classList.add('open');
    document.body.style.overflow = 'hidden';
  }
}
function adtCloseMobileMenu() {
  document.getElementById('mobileDrawer').classList.remove('open');
  document.getElementById('mobileDrawerOverlay').classList.remove('open');
  document.body.style.overflow = '';
}
// Close on escape key
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') adtCloseMobileMenu();
});

$(document).ready(function() {
  // Tooltips
  $('[rel=tooltip]').each(function() { new bootstrap.Tooltip(this); });

  // Popovers
  $('[rel=popover]').each(function() {
    new bootstrap.Popover(this, { trigger:'hover', html:true, sanitize:false, container:'body', delay:{show:80,hide:80} });
  });

  // Live status counter (parse visible status icons)
  var up = 0, down = 0;
  $('.fa-circle.text-success').each(function(){ up++; });
  $('.fa-circle.text-danger').each(function(){ down++; });
  var total = up + down;
  if (total > 0) {
    $('#sb-online').text(up + ' / ' + total);
    $('#sb-down').text(down);
    $('#sb-total').text(total);
  }
});
</script>
<?php
}

/* ═══════════════════════════════════════════════════════════════
   SECTION HELPER — replaces category-row for grouped pages
   ═══════════════════════════════════════════════════════════════ */

function buildTableTitleDev($plf_branch) {
  $typeMap = [
    '7.2.x' => ['label' => 'R&D', 'class' => 'type-rd',    'title' => "Platform or Meeds {$plf_branch} based builds (R&D) — next product release (no date yet)"],
    '7.1.x' => ['label' => 'Maint', 'class' => 'type-maint','title' => "Platform {$plf_branch} based builds (Maintenance)"],
    '7.0.x' => ['label' => 'Maint', 'class' => 'type-maint','title' => "Platform {$plf_branch} based builds (Maintenance)"],
    '6.5.x' => ['label' => 'Maint', 'class' => 'type-maint','title' => "Platform {$plf_branch} based builds (Maintenance)"],
    '6.4.x' => ['label' => 'Maint', 'class' => 'type-maint','title' => "Platform {$plf_branch} based builds (Maintenance)"],
    '6.3.x' => ['label' => 'Maint', 'class' => 'type-maint','title' => "Platform {$plf_branch} based builds (Maintenance)"],
    '6.2.x' => ['label' => 'Maint', 'class' => 'type-maint','title' => "Platform {$plf_branch} based builds (Maintenance)"],
    '6.1.x' => ['label' => 'Maint', 'class' => 'type-maint','title' => "Platform {$plf_branch} based builds (Maintenance)"],
    '6.0.x' => ['label' => 'Maint', 'class' => 'type-maint','title' => "Platform {$plf_branch} based builds (Maintenance)"],
    'COMPANY'  => ['label' => 'Co',   'class' => 'type-co',   'title' => "Company internal projects"],
    'CODEFEST' => ['label' => 'Fest', 'class' => 'type-co',   'title' => "eXo Codefest"],
    'UNKNOWN'  => ['label' => '?',    'class' => 'type-gray', 'title' => "Unclassified projects"],
  ];

  $m = $typeMap[$plf_branch] ?? null;

  if (!$m) {
    if (strpos($plf_branch, 'Demo') !== false) {
      $m = ['label'=>'Demo','class'=>'type-trans','title'=>"Platform {$plf_branch}s"];
    } elseif (in_array($plf_branch, ['1.0.x','1.1.x','1.2.x','1.3.x','1.4.x','1.5.x'])) {
      $m = ['label'=>'Meeds','class'=>'type-rd','title'=>"Platform {$plf_branch} based builds (Meeds)"];
    } elseif (in_array($plf_branch, ['5.x'])) {
      $m = ['label'=>'R&D','class'=>'type-rd','title'=>"Platform {$plf_branch} based builds (R&D) — perhaps next features ;-)"];
    } else {
      $m = ['label'=>'Maint','class'=>'type-maint','title'=>"Platform {$plf_branch} based builds (Maintenance)"];
    }
  }

  // Return the content that will go inside td.category-row
  return '<span class="group-type-tag ' . $m['class'] . ' me-2">' . $m['label'] . '</span>' . $m['title'];
}

/* ═══════════════════════════════════════════════════════════════
   COMPONENT FUNCTIONS
   ═══════════════════════════════════════════════════════════════ */

function componentLabels($d) {
  $out = "";
  if (property_exists($d, 'DEPLOYMENT_LABELS')) {
    $labels = is_array($d->DEPLOYMENT_LABELS) ? $d->DEPLOYMENT_LABELS : [$d->DEPLOYMENT_LABELS];
    foreach ($labels as $l) $out .= '<span class="label label-label me-1">' . $l . '</span>';
  }
  return $out;
}

function componentAddonsTags($d) {
  $out = componentAddonsDistributionTags($d) . ' ';
  if (property_exists($d, 'DEPLOYMENT_ADDONS')) {
    $addons = is_array($d->DEPLOYMENT_ADDONS) ? $d->DEPLOYMENT_ADDONS : [$d->DEPLOYMENT_ADDONS];
    foreach ($addons as $addon) {
      $parts = explode(':', $addon, 2);
      $ver   = isset($parts[1]) ? $parts[1] : 'latest';
      $out  .= '<span class="label label-addon me-1" rel="tooltip" title="version: ' . $ver . '">' . $parts[0] . '</span>';
    }
  }
  return $out;
}

function componentAddonsDistributionTags($d) {
  return '<span class="badge bg-secondary me-1" rel="tooltip" title="distribution add-ons: ' . $d->PRODUCT_ADDONS_DISTRIB . '"><i class="fas fa-gift"></i></span>';
}

function componentUpgradeEligibility($d, $badge = true) {
  if (property_exists($d,'INSTANCE_TOKEN') && $d->INSTANCE_TOKEN) {
    return $badge
      ? '<span class="badge bg-info me-1" rel="tooltip" title="Eligible for upgrades"><i class="fas fa-flag"></i></span>'
      : '<span rel="tooltip" title="Eligible for upgrades"><i class="fas fa-flag"></i></span>';
  }
  return '';
}

function componentPatchInstallation($d, $badge = true) {
  if (property_exists($d,'DEPLOYMENT_PATCHES') && $d->DEPLOYMENT_PATCHES) {
    return $badge
      ? '<span class="badge bg-success me-1" rel="tooltip" title="' . $d->DEPLOYMENT_PATCHES . ' installed"><i class="fas fa-plus-circle"></i></span>'
      : '<span rel="tooltip" title="' . $d->DEPLOYMENT_PATCHES . ' installed"><i class="fas fa-plus-circle"></i></span>';
  }
  return '';
}

function componentStagingModeEnabled($d, $badge = true) {
  if (property_exists($d,'DEPLOYMENT_STAGING_ENABLED') && $d->DEPLOYMENT_STAGING_ENABLED) {
    return $badge
      ? '<span class="badge bg-warning me-1" rel="tooltip" title="Staging mode enabled"><i class="fas fa-fire"></i></span>'
      : '<span rel="tooltip" title="Staging mode enabled"><i class="fas fa-fire"></i></span>';
  }
  return '';
}

function componentDevModeEnabled($d, $badge = true) {
  if (property_exists($d,'DEPLOYMENT_DEV_ENABLED') && $d->DEPLOYMENT_DEV_ENABLED) {
    return $badge
      ? '<span class="badge bg-dark me-1" rel="tooltip" title="Dev mode enabled"><i class="fab fa-github"></i></span>'
      : '<span rel="tooltip" title="Dev mode enabled"><i class="fab fa-github"></i></span>';
  }
  return '';
}

function componentDebugModeEnabled($d, $badge = true) {
  if (property_exists($d,'DEPLOYMENT_DEBUG_ENABLED') && $d->DEPLOYMENT_DEBUG_ENABLED) {
    return $badge
      ? '<span class="badge bg-danger me-1" rel="tooltip" title="Debug mode enabled"><i class="fas fa-stethoscope"></i></span>'
      : '<span rel="tooltip" title="Debug mode enabled"><i class="fas fa-stethoscope"></i></span>';
  }
  return '';
}

function componentCertbotEnabled($d, $badge = true) {
  if (property_exists($d,'DEPLOYMENT_CERTBOT_ENABLED') && $d->DEPLOYMENT_CERTBOT_ENABLED) {
    return $badge
      ? '<span class="badge bg-primary me-1" rel="tooltip" title="SSL via Certbot"><i class="fas fa-certificate"></i></span>'
      : '<span rel="tooltip" title="SSL via Certbot"><i class="fas fa-certificate"></i></span>';
  }
  return '';
}

function componentStatusIcon($d) {
  if ($d->DEPLOYMENT_STATUS === "Up") {
    return '<i class="fas fa-circle text-success" rel="tooltip" title="Up"></i>';
  }
  return '<i class="fas fa-circle text-danger" rel="tooltip" title="Down"></i>';
}

function componentAppServerIcon($d) {
  $type = strtolower($d->DEPLOYMENT_APPSRV_TYPE);
  $icon = in_array($type, ['tomcat']) ? 'fa-brands fa-java' : ($type === 'jboss' || $type === 'wildfly' ? 'fa-brands fa-redhat' : 'fa-server');
  return '<i class="fas ' . $icon . '" rel="tooltip" title="App server: ' . $d->DEPLOYMENT_APPSRV_TYPE . '"></i>';
}

function componentEditNoteIcon($d) {
  $id  = 'edit-note-' . str_replace('.', '_', $d->INSTANCE_KEY);
  $out = '<a href="#" rel="tooltip" title="Edit instance note" data-bs-toggle="modal" data-bs-target="#' . $id . '"><i class="fas fa-pencil-alt"></i></a>';
  $out .= getFormEditNote($d);
  return $out;
}

function componentSpecificationIcon($d) {
  if (!empty($d->SPECIFICATIONS_LINK)) {
    return '<a rel="tooltip" title="Specifications" href="' . $d->SPECIFICATIONS_LINK . '" target="_blank"><i class="fas fa-book"></i></a>';
  }
  return '';
}

function componentDatabaseIcon($d) {
  $db = $d->DATABASE;
  if     (stripos($db,'mysql')    !== false) { $t='MySQL';     $c='text-warning'; }
  elseif (stripos($db,'mariadb')  !== false) { $t='MariaDB';   $c='text-success'; }
  elseif (stripos($db,'postgres') !== false) { $t='PostgreSQL';$c='text-info';    }
  elseif (stripos($db,'oracle')   !== false) { $t='Oracle';    $c='text-danger';  }
  elseif (stripos($db,'sqlserver')!== false) { $t='SQL Server';$c='text-secondary';}
  elseif (stripos($db,'h2')       !== false) { $t='H2';        $c='text-secondary';}
  else                                        { $t='DB';        $c='text-secondary';}

  $out = '<i class="fas fa-database ' . $c . ' me-1" rel="tooltip" title="' . $t . '"></i>';
  if (empty($d->DEPLOYMENT_DATABASE_VERSION)) {
    $out .= '<span class="badge bg-secondary">-NC-</span>';
  } else {
    $out .= '<span class="badge bg-info">' . $d->DEPLOYMENT_DATABASE_VERSION . '</span>';
  }
  return $out;
}

function componentVisibilityIcon($d, $color = '') {
  $icon = $d->DEPLOYMENT_APACHE_SECURITY === 'public' ? 'fa-globe'
       : ($d->DEPLOYMENT_APACHE_SECURITY === 'private' ? 'fa-lock' : 'fa-question-circle');
  $cls  = $color ? ' text-' . $color : '';
  return '<i class="fas ' . $icon . $cls . '" rel="tooltip" title="Visibility: ' . $d->DEPLOYMENT_APACHE_SECURITY . '"></i>';
}

function componentProductInfoIcon($d) {
  return '<a href="#" rel="popover" data-bs-content="' . htmlspecialchars(componentProductHtmlPopover($d)) . '" data-bs-html="true" data-bs-trigger="hover"><i class="fas fa-info-circle text-info"></i></a>';
}

function componentDownloadIcon($d) {
  $content  = '<strong>GroupId:</strong> ' . $d->ARTIFACT_GROUPID . '<br>';
  $content .= '<strong>ArtifactId:</strong> ' . $d->ARTIFACT_ARTIFACTID . '<br>';
  $content .= '<strong>Version:</strong> ' . $d->ARTIFACT_TIMESTAMP;
  return '<a href="' . $d->ARTIFACT_DL_URL . '" rel="popover" data-bs-content="' . htmlspecialchars($content) . '" data-bs-html="true" data-bs-trigger="hover"><i class="fas fa-download"></i></a>';
}

function componentProductHtmlLabel($d, $simple = false) {
  $out = empty($d->PRODUCT_DESCRIPTION) ? $d->PRODUCT_NAME : $d->PRODUCT_DESCRIPTION;
  if (!empty($d->INSTANCE_ID)) $out .= ' (' . $d->INSTANCE_ID . ')';
  if (!$simple) {
    if (!empty($d->BRANCH_DESC))    $out = '<span class="muted">' . $out . '</span>&nbsp;&mdash;&nbsp;' . $d->BRANCH_DESC;
    if (!empty($d->INSTANCE_NOTE))  $out = '<span class="muted">' . $out . '</span>&nbsp;&mdash;&nbsp;' . $d->INSTANCE_NOTE;
  }
  return $out;
}

function componentProductOpenLink($d, $text = '', $ssl = false) {
  $https = $d->DEPLOYMENT_APACHE_HTTPS_ENABLED;
  $url   = $d->DEPLOYMENT_APACHE_VHOST_ALIAS ? 'http://' . $d->DEPLOYMENT_APACHE_VHOST_ALIAS : $d->DEPLOYMENT_URL;
  if (isInstanceBuyPage($d)) $url .= '/buy/';

  $href = ($ssl && $https) ? preg_replace('/http:(.*)/', 'https:$1', $url) : $url;
  $label = empty($text) ? componentProductHtmlLabel($d) : $text;
  $out = '<a href="' . $href . '" target="_blank">' . $label . '</a>';

  if (!$ssl && $https) {
    $sslUrl = preg_replace('/http:(.*)/', 'https:$1', $url);
    $out .= ' <a rel="tooltip" title="HTTPS available" href="' . $sslUrl . '" target="_blank"><i class="fas fa-lock text-success"></i></a>';
  }
  return $out;
}

function componentProductVersion($d) {
  if (preg_match('/.*-M(LT|BL)$/', $d->BASE_VERSION)) {
    $msg = (preg_match('/.*-MBL$/', $d->BASE_VERSION) ? 'Before latest' : 'Latest') . ' milestone CD enabled';
    return $d->ARTIFACT_TIMESTAMP . ' <span class="version-sub" rel="tooltip" title="' . $msg . '">Auto</span>';
  }
  $out  = $d->BASE_VERSION;
  $tail = substr_replace($d->ARTIFACT_TIMESTAMP, '', 0, strlen($d->BASE_VERSION));
  if (!empty($tail)) {
    $out .= '<span class="version-sub" rel="tooltip" title="' . $d->ARTIFACT_TIMESTAMP . '">';
    if (!empty($d->BRANCH_NAME)) $out .= '-' . $d->BRANCH_NAME;
    $out .= '-SNAPSHOT</span>';
  }
  return $out;
}

function componentProductHtmlPopover($d) {
  $out  = '<div style="min-width:220px;font-size:12px;line-height:1.7">';
  $out .= '<strong>Product:</strong> ' . componentProductHtmlLabel($d) . '<br>';
  $out .= '<strong>Version:</strong> ' . $d->PRODUCT_VERSION . '<br>';
  $out .= '<strong>Server:</strong> ' . $d->DEPLOYMENT_APPSRV_TYPE . '<br>';
  $out .= '<strong>Database:</strong> ' . $d->DATABASE . '<br>';
  $out .= '<strong>Visibility:</strong> ' . $d->DEPLOYMENT_APACHE_SECURITY . '<br>';
  $out .= '<strong>HTTPS:</strong> ' . ($d->DEPLOYMENT_APACHE_HTTPS_ENABLED ? '✓ yes' : '✗ no') . '<br>';
  $out .= '<strong>ES embedded:</strong> ' . ($d->DEPLOYMENT_ES_EMBEDDED ? '✓ yes' : '✗ no') . '<br>';
  $out .= '<strong>OnlyOffice:</strong> ' . ($d->DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED ? '✓ yes' : '✗ no') . '<br>';
  if ($d->DEPLOYMENT_CHAT_ENABLED) {
    $out .= '<strong>Chat embedded:</strong> ' . ($d->DEPLOYMENT_CHAT_EMBEDDED ? '✓ yes' : '✗ no') . '<br>';
    $out .= '<strong>MongoDB:</strong> v' . $d->DEPLOYMENT_CHAT_MONGODB_VERSION . '<br>';
  }
  $out .= '<strong>Virtual Host:</strong> ' . preg_replace('/https?:\/\/(.*)/', '$1', $d->DEPLOYMENT_URL);
  if ($d->DEPLOYMENT_APACHE_VHOST_ALIAS) $out .= '<br><strong>Alias:</strong> ' . $d->DEPLOYMENT_APACHE_VHOST_ALIAS;
  if ($d->DEPLOYMENT_INFO) $out .= '<hr><strong>Info:</strong> ' . $d->DEPLOYMENT_INFO;
  $out .= '</div>';
  return $out;
}

function componentDeploymentActions($d) {
  $host = $d->DEPLOYMENT_EXT_HOST;
  if (property_exists($d,'DEPLOYMENT_APACHE_VHOST_ALIAS') && $d->DEPLOYMENT_APACHE_VHOST_ALIAS)
    $host = $d->DEPLOYMENT_APACHE_VHOST_ALIAS;

  $b = '<div class="btn-group btn-group-sm" role="group">';
  $b .= _ab($d->DEPLOYMENT_LOG_APPSRV_URL, 'fa-file-alt',   'Instance logs');
  $b .= _ab($d->DEPLOYMENT_LOG_APACHE_URL, 'fa-server',     'Apache logs');
  if (!empty($d->DEPLOYMENT_JMX_URL))
    $b .= _ab($d->DEPLOYMENT_JMX_URL, 'fa-chart-line', 'JMX monitoring');
  if (!empty($d->DEPLOYMENT_LDAP_LINK))
    $b .= _ab($d->DEPLOYMENT_LDAP_LINK, 'fa-address-book', 'LDAP');
  if (property_exists($d,'DEPLOYMENT_CRASH_ENABLED') && $d->DEPLOYMENT_CRASH_ENABLED)
    $b .= _ab('ssh://root@'.$d->DEPLOYMENT_EXT_HOST.':'.$d->DEPLOYMENT_CRASH_SSH_PORT,'fa-terminal','CRaSH SSH');
  $b .= _ab($d->DEPLOYMENT_AWSTATS_URL, 'fa-chart-bar', 'Statistics');
  if (property_exists($d,'DEPLOYMENT_ES_ENABLED') && $d->DEPLOYMENT_ES_ENABLED)
    $b .= _ab('http://'.$host.'/elasticsearch','fa-search','Elasticsearch');
  if (property_exists($d,'DEPLOYMENT_MAILPIT_ENABLED') && $d->DEPLOYMENT_MAILPIT_ENABLED)
    $b .= _ab('http://'.$host.'/mailpit/','fa-envelope','Mailpit');
  if (property_exists($d,'DEPLOYMENT_MONGO_EXPRESS_ENABLED') && $d->DEPLOYMENT_MONGO_EXPRESS_ENABLED)
    $b .= _ab('http://'.$host.'/mongoexpress/','fa-database','Mongo Express');
  if (property_exists($d,'DEPLOYMENT_KEYCLOAK_ENABLED') && $d->DEPLOYMENT_KEYCLOAK_ENABLED)
    $b .= _ab('http://'.$host.'/auth/admin/','fa-key','Keycloak');
  if (property_exists($d,'DEPLOYMENT_CLOUDBEAVER_ENABLED') && $d->DEPLOYMENT_CLOUDBEAVER_ENABLED)
    $b .= _ab('http://'.$host.'/cloudbeaver/','fa-cloud','CloudBeaver');
  if (property_exists($d,'DEPLOYMENT_PHPLDAPADMIN_ENABLED') && $d->DEPLOYMENT_PHPLDAPADMIN_ENABLED)
    $b .= _ab('http://'.$d->DEPLOYMENT_EXT_HOST.':'.$d->DEPLOYMENT_PHPLDAPADMIN_HTTP_PORT,'fa-address-book','phpLDAPAdmin');
  if (property_exists($d,'DEPLOYMENT_SFTP_ENABLED') && $d->DEPLOYMENT_SFTP_ENABLED)
    $b .= _ab($d->DEPLOYMENT_SFTP_LINK,'fa-file-export','SFTP');
  if (property_exists($d,'DEPLOYMENT_CMISSERVER_ENABLED') && $d->DEPLOYMENT_CMISSERVER_ENABLED)
    $b .= _ab('http://'.$d->DEPLOYMENT_EXT_HOST.'/cmis','fa-share-alt','CMIS');
  if (property_exists($d,'DEPLOYMENT_FRONTAIL_ENABLED') && $d->DEPLOYMENT_FRONTAIL_ENABLED)
    $b .= _ab('http://'.$host.'/livelogs/','fa-play-circle','Live logs');
  $b .= '</div>';
  return $b;
}

function _ab($url, $icon, $title) {
  return '<a href="' . $url . '" rel="tooltip" title="' . $title . '" target="_blank" class="btn btn-outline-secondary">'
       . '<i class="fas ' . $icon . '"></i></a>';
}

function componentFBStatusLabel($d) {
  $map = [
    'Implementing'      => 'fb-implementing',
    'Engineering Review'=> 'fb-review',
    'QA Review'         => 'fb-review',
    'QA In Progress'    => 'fb-review',
    'QA Rejected'       => 'fb-rejected',
    'Validated'         => 'fb-validated',
    'Merged'            => 'fb-merged',
  ];
  $cls = $map[$d->ACCEPTANCE_STATE] ?? 'fb-implementing';
  return '<span class="fb-state ' . $cls . '">' . $d->ACCEPTANCE_STATE . '</span>';
}

function componentFBScmLabel($d) {
  if (!empty($d->SCM_BRANCH)) {
    $anchor = str_replace(['/','.'], '-', $d->SCM_BRANCH);
    return '<a href="/features.php#' . $anchor . '" rel="tooltip" title="SCM branch">'
         . '<i class="fas fa-code-branch me-1"></i>' . $d->SCM_BRANCH . '</a>';
  }
  return '-';
}

function componentFBIssueLabel($d) {
  if (!empty($d->ISSUE_NUM)) {
    return '<a href="https://community.exoplatform.com/portal/dw/tasks/taskDetail/' . $d->ISSUE_NUM . '" rel="tooltip" title="Issue">'
         . '<i class="fas fa-tasks me-1"></i>' . $d->ISSUE_NUM . '</a>';
  }
  return '-';
}

function componentFBEditIcon($d) {
  $id  = 'edit-' . str_replace('.', '_', $d->INSTANCE_KEY);
  $out = '<a href="#" rel="tooltip" title="Edit feature branch" data-bs-toggle="modal" data-bs-target="#' . $id . '"><i class="fas fa-pencil-alt"></i></a>';
  $out .= getFormEditFeatureBranch($d);
  return $out;
}

function componentFBDeployIcon($d) {
  if (isset($d->DEPLOYMENT_BUILD_URL)) {
    return '<a href="' . $d->DEPLOYMENT_BUILD_URL . '/build?delay=0sec" rel="tooltip" title="Restart / reset" target="_blank"><i class="fas fa-sync-alt"></i></a>';
  }
  return '';
}

function componentFeatureRepoBrancheStatus($fb, $cherry = false) {
  if ($cherry) {
    if ($fb['cherry_commits'] > 0) {
      return '<span class="commit-stat behind" rel="tooltip" title="' . $fb['cherry_commits'] . ' commits behind base">'
           . '<i class="fas fa-arrow-down"></i> ' . $fb['cherry_commits'] . '</span>';
    }
    return '<span class="commit-stat" rel="tooltip" title="Up to date"><i class="fas fa-check"></i></span>';
  }

  $out  = '<div class="commit-stats">';
  $out .= '<a href="' . $fb['http_url_behind'] . '" target="_blank" class="commit-stat ' . ($fb['behind_commits']>0?'behind':'') . '" rel="tooltip" title="' . $fb['behind_commits'] . ' commits behind">'
        . '<i class="fas fa-arrow-down"></i> ' . $fb['behind_commits'] . '</a>';
  $out .= '<a href="' . $fb['http_url_ahead'] . '" target="_blank" class="commit-stat ' . ($fb['ahead_commits']>0?'ahead':'') . '" rel="tooltip" title="' . $fb['ahead_commits'] . ' commits ahead">'
        . '<i class="fas fa-arrow-up"></i> ' . $fb['ahead_commits'] . '</a>';
  $out .= '</div>';
  return $out;
}
