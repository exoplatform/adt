<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
  <?= pageHeader("debug"); ?>
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
            
            <div class="card mb-4">
              <div class="card-header">
                <i class="fas fa-code text-primary me-2"></i>Debug Deployment Information
              </div>
              <div class="card-body">
<?php

echo "<h5 class='mb-3'>## getGlobalDevInstances()</h5>\n";
$instances=getGlobalDevInstances();
echo "<p>isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."</p>\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "<h6 class='mt-3'>$category :</h6>\n";
    echo "<ul class='list-unstyled ms-3'>\n";
    foreach ($instances_array as $instance) {
      echo "<li class='mb-1'><i class='fas fa-cube text-muted me-2'></i> $instance->INSTANCE_DESCRIPTION</li>\n";
    }
    echo "</ul>\n";
  }
  echo debug_var_toggle ($instances);
} else {
  echo "<div class='alert alert-warning'>-Nothing-</div>";
}
echo "<hr class='my-4' />\n";


echo "<h5 class='mb-3'>## getGlobalDocInstances()</h5>\n";
$instances=getGlobalDocInstances();
echo "<p>isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."</p>\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "<h6 class='mt-3'>$category :</h6>\n";
    echo "<ul class='list-unstyled ms-3'>\n";
    foreach ($instances_array as $instance) {
      echo "<li class='mb-1'><i class='fas fa-cube text-muted me-2'></i> $instance->INSTANCE_DESCRIPTION</li>\n";
    }
    echo "</ul>\n";
  }
  echo debug_var_toggle ($instances);
} else {
  echo "<div class='alert alert-warning'>-Nothing-</div>";
}
echo "<hr class='my-4' />\n";


echo "<h5 class='mb-3'>## getGlobalTranslationInstances()</h5>\n";
$instances=getGlobalTranslationInstances();
echo "<p>isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."</p>\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "<h6 class='mt-3'>$category :</h6>\n";
    echo "<ul class='list-unstyled ms-3'>\n";
    foreach ($instances_array as $instance) {
      echo "<li class='mb-1'><i class='fas fa-cube text-muted me-2'></i> $instance->INSTANCE_DESCRIPTION</li>\n";
    }
    echo "</ul>\n";
  }
  echo debug_var_toggle ($instances);
} else {
  echo "<div class='alert alert-warning'>-Nothing-</div>";
}
echo "<hr class='my-4' />\n";


echo "<h5 class='mb-3'>## getGlobalSalesUserInstances()</h5>\n";
$instances=getGlobalSalesUserInstances();
echo "<p>isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."</p>\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "<h6 class='mt-3'>$category :</h6>\n";
    echo "<ul class='list-unstyled ms-3'>\n";
    foreach ($instances_array as $instance) {
      echo "<li class='mb-1'><i class='fas fa-cube text-muted me-2'></i> $instance->INSTANCE_DESCRIPTION</li>\n";
    }
    echo "</ul>\n";
  }
  echo debug_var_toggle ($instances);
} else {
  echo "<div class='alert alert-warning'>-Nothing-</div>";
}
echo "<hr class='my-4' />\n";


echo "<h5 class='mb-3'>## getGlobalSalesDemoInstances()</h5>\n";
$instances=getGlobalSalesDemoInstances();
echo "<p>isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."</p>\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "<h6 class='mt-3'>$category :</h6>\n";
    echo "<ul class='list-unstyled ms-3'>\n";
    foreach ($instances_array as $instance) {
      echo "<li class='mb-1'><i class='fas fa-cube text-muted me-2'></i> $instance->INSTANCE_DESCRIPTION</li>\n";
    }
    echo "</ul>\n";
  }
  echo debug_var_toggle ($instances);
} else {
  echo "<div class='alert alert-warning'>-Nothing-</div>";
}
echo "<hr class='my-4' />\n";


echo "<h5 class='mb-3'>## getGlobalSalesEvalInstances()</h5>\n";
$instances=getGlobalSalesEvalInstances();
echo "<p>isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."</p>\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "<h6 class='mt-3'>$category :</h6>\n";
    echo "<ul class='list-unstyled ms-3'>\n";
    foreach ($instances_array as $instance) {
      echo "<li class='mb-1'><i class='fas fa-cube text-muted me-2'></i> $instance->INSTANCE_DESCRIPTION</li>\n";
    }
    echo "</ul>\n";
  }
  echo debug_var_toggle ($instances);
} else {
  echo "<div class='alert alert-warning'>-Nothing-</div>";
}
echo "<br />\n";


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