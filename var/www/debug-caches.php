<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
if (array_key_exists('refreshInstances', $_GET)) {
  refreshGlobalAcceptanceInstances();
  header("Location: /debug-caches");
  exit;
}
?>
<html lang="en">
<head>
  <?= pageHeader("debug - caches"); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
  <!-- Main ================================================== -->
  <div id="wrap">
    <div id="main">
      <div class="page-header">
        <h1 class="page-header__title">Debug Caches</h1>
        <p class="page-header__subtitle">APC / APCu / Memcache status</p>
      </div>
      <div class="container-fluid">
        <div class="row">
          <div class="col-12">
            <?= componentDebugMenu(); ?>

            <div class="card">
              <div class="card-header">
                <i class="fas fa-database me-2"></i>Cache Information
              </div>
              <div class="card-body">
<?php
// State of the cross-server instances cache: a fresh copy (2 min), a stale copy served while
// a refresh runs (30 min), and the lock preventing concurrent refreshes
if (extension_loaded('apcu') && function_exists('apcu_cache_info')) {
  $watched = array('all_instances' => 'Fresh instances (all servers)',
                   'all_instances_stale' => 'Stale instances, served while refreshing',
                   'all_instances_refreshing' => 'Background refresh scheduled',
                   'all_server_stats' => 'Server stats');
  $entries = array();
  foreach ((apcu_cache_info(false)['cache_list'] ?? array()) as $entry) {
    $entries[$entry['info']] = $entry;
  }
  echo '<table class="table table-sm"><thead><tr><th>Key</th><th>Role</th><th>Age</th><th>Expires in</th></tr></thead><tbody>';
  foreach ($watched as $key => $role) {
    $e = $entries[$key] ?? null;
    $age = $e ? (time() - $e['creation_time']) . 's' : '-';
    $left = $e ? (($e['ttl'] > 0) ? max(0, $e['creation_time'] + $e['ttl'] - time()) . 's' : 'never') : 'not cached';
    echo '<tr><td><code>' . htmlspecialchars($key) . '</code></td><td>' . htmlspecialchars($role) . '</td><td>' . $age . '</td><td>' . $left . '</td></tr>';
  }
  echo '</tbody></table>';
  echo '<p><a class="btn btn-sm btn-outline-primary" href="/debug-caches?refreshInstances=true">Refresh instances now</a> ';
  echo '<a class="btn btn-sm btn-outline-danger" href="/debug-caches?clearCaches=true">Clear all caches</a></p>';
}
if (extension_loaded('apc') && function_exists('apc_cache_info')) {
  echo '<div class="alert alert-info">APC Cache</div>';
  echo debug_var(apc_cache_info('user'), true);
} elseif (extension_loaded('apcu') && function_exists('apcu_cache_info')) {
  echo '<div class="alert alert-info">APCu Cache</div>';
  echo debug_var(apcu_cache_info('user'), true);
} elseif (extension_loaded('memcache') && function_exists('memcache_flush')) {
  echo '<div class="alert alert-info">Memcache</div>';
  echo debug_var(memcache_flush(), true);
} else {
  echo '<div class="alert alert-warning">-Nothing-</div>';
}
?>
              </div>
            </div>
          </div>
        </div>
      </div>
    <!-- /container -->
    </div>
  </div>
<?php pageFooter(); ?>
</body>
</html>