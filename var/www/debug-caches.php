<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
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