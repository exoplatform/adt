<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html lang="en">
<head>
  <?= pageHeader("debug - deployment"); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
  <!-- Main ================================================== -->
  <div id="wrap">
    <div id="main">
      <div class="page-header">
        <h1 class="page-header__title">Debug Deployment</h1>
        <p class="page-header__subtitle">Raw dump of every instance-category getter</p>
      </div>
      <div class="container-fluid">
        <div class="row">
          <div class="col-12">
            <?= componentDebugMenu(); ?>

            <div class="card mb-4">
              <div class="card-header">
                <i class="fas fa-code text-primary me-2"></i>Debug Deployment Information
              </div>
              <div class="card-body">
<?php
$categoryGetters = [
  'getGlobalDevInstances',
  'getGlobalDocInstances',
  'getGlobalTranslationInstances',
  'getGlobalSalesUserInstances',
  'getGlobalSalesDemoInstances',
  'getGlobalSalesEvalInstances',
];
foreach ($categoryGetters as $getter) {
  echo "<h5 class='mb-3'>## {$getter}()</h5>\n";
  $instances = $getter();
  echo "<p>isDeploymentInCategoryArray=" . debug_var(isDeploymentInCategoryArray($instances)) . "</p>\n";
  if (isDeploymentInCategoryArray($instances)) {
    foreach ($instances as $category => $instances_array) {
      echo "<h6 class='mt-3'>" . htmlspecialchars($category) . " :</h6>\n";
      echo "<ul class='list-unstyled ms-3'>\n";
      foreach ($instances_array as $instance) {
        echo "<li class='mb-1'><i class='fas fa-cube text-muted me-2'></i> " . htmlspecialchars($instance->INSTANCE_DESCRIPTION) . "</li>\n";
      }
      echo "</ul>\n";
    }
    echo debug_var_toggle($instances);
  } else {
    echo "<div class='alert alert-warning'>-Nothing-</div>";
  }
  echo "<hr class='my-4' />\n";
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