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

// Git Repositories
echo "## getRepositories<br />\n";
$projectsNames = getRepositories();
echo debug_var_toggle($projectsNames);
echo "<br />\n";

// Git Feature Branches
echo "## getFeatureBranches(projects)<br />\n";
$projects = array_keys($projectsNames);
$projects_FB=getFeatureBranches($projects);
echo debug_var_toggle($projects_FB);
echo "<br />\n";

// Translation Branches
echo "## getTranslationBranches(projects)<br />\n";
$projects_TB=getTranslationBranches($projects);
foreach ($projects_TB as $project_key => $project_TB) {
  echo "$project_key <br />\n";
}
echo debug_var_toggle($projects_TB);
echo "<br />\n";

// Acceptance Branches
echo "## getAcceptanceBranches()<br />\n";
$projects_AB=getAcceptanceBranches();
foreach ($projects_AB as $project_AB) {
  echo "$project_AB <br />\n";
}
echo debug_var_toggle($projects_AB);
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
