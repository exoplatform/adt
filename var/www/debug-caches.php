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
        <div class="row-fluid">
          <ul>
            <li><a href="/debug-git.php">Debug Git functions</a></li>
            <li><a href="/debug-deploy.php">Debug Deployment</a></li>
            <li><a href="/debug-caches.php">Debug Caches</a> (<a href="/debug-caches.php?clearCaches=true">Clear all Caches</a>)</li>
          </ul>
<?php
if (extension_loaded('apc') && function_exists('apc_cache_info')) {
  echo debug_var(apc_cache_info('user'), true);
} elseif (extension_loaded('memcache') && function_exists('memcache_flush')) {
  echo debug_var(memcache_flush(), true);
}
?>
        </div>
      </div>
    <!-- /container -->
    </div>
  </div>
<?php pageFooter(); ?>
</body>
</html>
