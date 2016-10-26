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
<?php
function my_print_r($array) {
  echo "<pre>\n";
  print_r ($array);
  echo "\n</pre>\n";
}

my_print_r(apc_cache_info('user'));
?>
        </div>
      </div>
    <!-- /container -->
    </div>
  </div>
<?php pageFooter(); ?>
</body>
</html>
