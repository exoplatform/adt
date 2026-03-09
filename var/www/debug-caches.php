<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
  <?= pageHeader("debug - caches"); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
  <!-- Main ================================================== -->
  <div id="wrap">
    <div id="main">
      <div class="container-fluid">
        <div class="row">
          <div class="col-12">
            <div class="card mb-4">
              <div class="card-header">
                <i class="fas fa-bug me-2"></i>Debug Menu
              </div>
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
            
            <div class="card">
              <div class="card-header">
                <i class="fas fa-database me-2"></i>Cache Information
              </div>
              <div class="card-body">
<?php
if (extension_loaded('apc') && function_exists('apc_cache_info')) {
  echo '<div class="alert alert-info">APC Cache</div>';
  echo debug_var(apc_cache_info('user'), true);
} elseif (extension_loaded('apcu') && function_exists('apcu_cache_info')) {
  echo '<div class="alert alert-info">APCu Cache</div>';
  echo debug_var(apcu_cache_info('user'), true);
} elseif (extension_loaded('memcache') && function_exists('memcache_flush')) {
  echo '<div class="alert alert-info">Memcache</div>';
  echo debug_var(memcache_flush(), true);
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