<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
  <?= pageHeader("debug"); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
  <div id="main">
    <div class="page-header">
      <h1 class="page-header__title">Debug</h1>
    </div>
    <div class="container-fluid">
      <div class="row">
        <div class="col-12">
          <?= componentDebugMenu(); ?>
        </div>
      </div>
    </div>
    <!-- /container -->
  </div>
</div>
<?php pageFooter(); ?>
</body>
</html>