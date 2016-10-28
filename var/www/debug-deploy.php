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
        <div class="row-fluid">
          <ul>
            <li><a href="/debug-git.php">Debug Git functions</a></li>
            <li><a href="/debug-deploy.php">Debug Deployment</a></li>
            <li><a href="/debug-caches.php">Debug Caches</a> (<a href="/debug-caches.php?clearCaches=true">Clear all Caches</a>)</li>
          </ul>
<?php

echo "## getGlobalDevInstances()<br />\n";
$instances=getGlobalDevInstances();
echo "isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."<br />\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "$category : <br />\n";
    foreach ($instances_array as $instance) {
      echo "&nbsp;&nbsp;&nbsp; $instance->INSTANCE_DESCRIPTION<br />\n";
    }
  }
  echo debug_var_toggle ($instances);
} else {
  echo "-Nothing-";
}
echo "<br />\n";


echo "## getGlobalDocInstances()<br />\n";
$instances=getGlobalDocInstances();
echo "isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."<br />\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "$category : <br />\n";
    foreach ($instances_array as $instance) {
      echo "&nbsp;&nbsp;&nbsp; $instance->INSTANCE_DESCRIPTION<br />\n";
    }
  }
  echo debug_var_toggle ($instances);
} else {
  echo "-Nothing-";
}
echo "<br />\n";


echo "## getGlobalTranslationInstances()<br />\n";
$instances=getGlobalTranslationInstances();
echo "isDeploymentInCategoryArray=".debug_var(isDeploymentInCategoryArray($instances))."<br />\n";
if (isDeploymentInCategoryArray($instances)) {
  foreach ($instances as $category => $instances_array) {
    echo "$category : <br />\n";
    foreach ($instances_array as $instance) {
      echo "&nbsp;&nbsp;&nbsp; $instance->INSTANCE_DESCRIPTION<br />\n";
    }
  }
  echo debug_var_toggle ($instances);
} else {
  echo "-Nothing-";
}
echo "<br />\n";


?>
</div>
</div>
<!-- /container -->
</div>
</div>
<?php pageFooter(); ?>
</body>
</html>
