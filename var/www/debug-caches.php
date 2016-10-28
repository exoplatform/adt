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

echo debug_var(apc_cache_info('user'), true);
?>
        </div>
      </div>
    <!-- /container -->
    </div>
  </div>
<?php pageFooter(); ?>
</body>
</html>
