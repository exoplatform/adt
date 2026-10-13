<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'delete-key') {
  if (!hash_equals(sessionsCsrfToken(), (string)($_POST['token'] ?? ''))) {
    http_response_code(403);
    exit('Invalid token');
  }
  $key = (string)($_POST['key'] ?? '');
  if (extension_loaded('apcu') && function_exists('apcu_delete') && apcu_exists($key)) {
    apcu_delete($key);
    auditLog('cache.delete-key', ['key' => $key]);
  }
  header("Location: /debug-caches");
  exit;
}
if (array_key_exists('refreshInstances', $_GET)) {
  auditLog('cache.refresh-instances');
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
  echo '<div class="table-responsive"><table class="table table-sm"><thead><tr><th>Key</th><th>Role</th><th>Age</th><th>Expires in</th></tr></thead><tbody>';
  foreach ($watched as $key => $role) {
    $e = $entries[$key] ?? null;
    $age = $e ? (time() - $e['creation_time']) . 's' : '-';
    $left = $e ? (($e['ttl'] > 0) ? max(0, $e['creation_time'] + $e['ttl'] - time()) . 's' : 'never') : 'not cached';
    echo '<tr><td><code>' . htmlspecialchars($key) . '</code></td><td>' . htmlspecialchars($role) . '</td><td>' . $age . '</td><td>' . $left . '</td></tr>';
  }
  echo '</tbody></table></div>';
  echo '<p><a class="btn btn-sm btn-outline-primary" href="/debug-caches?refreshInstances=true">Refresh instances now</a> ';
  echo '<a class="btn btn-sm btn-outline-danger" href="/debug-caches?clearCaches=true">Clear all caches</a></p>';

  // Memory and hit rate
  $stats = apcu_cache_info(true);
  $sma = function_exists('apcu_sma_info') ? apcu_sma_info(true) : null;
  $hits = (int)($stats['num_hits'] ?? 0);
  $misses = (int)($stats['num_misses'] ?? 0);
  echo '<h6 class="mt-4">APCu usage</h6><table class="table table-sm w-auto"><tbody>';
  echo '<tr><th scope="row">Entries</th><td>' . (int)($stats['num_entries'] ?? 0) . '</td></tr>';
  echo '<tr><th scope="row">Hits / misses</th><td>' . $hits . ' / ' . $misses . ($hits + $misses ? ' (' . round(100 * $hits / ($hits + $misses)) . '% hit rate)' : '') . '</td></tr>';
  if ($sma) {
    $total = (int)$sma['num_seg'] * (int)$sma['seg_size'];
    echo '<tr><th scope="row">Memory</th><td>' . debugBytes($total - (int)$sma['avail_mem']) . ' / ' . debugBytes($total) . '</td></tr>';
  }
  echo '<tr><th scope="row">Up since</th><td>' . gmdate('Y-m-d H:i', (int)($stats['start_time'] ?? 0)) . ' UTC</td></tr>';
  echo '</tbody></table>';

  // Every entry, each one can be dropped on its own
  $list = array_values($entries);
  usort($list, fn($a, $b) => strcmp($a['info'], $b['info']));
  $token = sessionsCsrfToken();
  echo '<h6 class="mt-4">Entries (' . count($list) . ')</h6>';
  echo '<div class="table-responsive"><table class="table table-sm align-middle"><thead><tr><th>Key</th><th>Size</th><th>Hits</th><th>Age</th><th>Expires in</th><th></th></tr></thead><tbody>';
  foreach (array_slice($list, 0, 300) as $e) {
    $left = ($e['ttl'] > 0) ? max(0, $e['creation_time'] + $e['ttl'] - time()) . 's' : 'never';
    echo '<tr><td class="text-break"><code>' . htmlspecialchars($e['info']) . '</code></td><td>' . debugBytes($e['mem_size'] ?? 0) . '</td><td>' . (int)($e['num_hits'] ?? 0)
      . '</td><td>' . (time() - $e['creation_time']) . 's</td><td>' . $left . '</td><td>'
      . '<form method="post" class="d-inline"><input type="hidden" name="action" value="delete-key"><input type="hidden" name="token" value="' . $token . '">'
      . '<input type="hidden" name="key" value="' . htmlspecialchars($e['info'], ENT_QUOTES) . '"><button class="btn btn-sm btn-outline-danger" type="submit">Delete</button></form></td></tr>';
  }
  if (!$list) {
    echo '<tr><td colspan="6" class="text-muted">The cache is empty.</td></tr>';
  }
  echo '</tbody></table></div>';
}
if (extension_loaded('memcache') && !empty($GLOBALS['memcache']) && method_exists($GLOBALS['memcache'], 'getStats')) {
  $mc = @$GLOBALS['memcache']->getStats();
  if (is_array($mc)) {
    echo '<h6 class="mt-4">Memcache usage</h6><table class="table table-sm w-auto"><tbody>';
    foreach (['curr_items' => 'Items', 'get_hits' => 'Hits', 'get_misses' => 'Misses', 'bytes' => 'Memory used', 'limit_maxbytes' => 'Memory limit', 'uptime' => 'Uptime (s)'] as $k => $label) {
      if (isset($mc[$k])) {
        echo '<tr><th scope="row">' . $label . '</th><td>' . (in_array($k, ['bytes', 'limit_maxbytes'], true) ? debugBytes($mc[$k]) : (int)$mc[$k]) . '</td></tr>';
      }
    }
    echo '</tbody></table>';
  }
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