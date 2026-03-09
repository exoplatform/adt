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
            
            <div class="card">
              <div class="card-header">
                <i class="fab fa-git-alt me-2"></i>Git Debug Information
              </div>
              <div class="card-body">
<?php

// Git Repositories
echo "<h5 class='mb-3'>## getRepositories</h5>\n";
$projectsNames = getRepositories();
echo debug_var_toggle($projectsNames);
echo "<hr class='my-4' />\n";

// Git Feature Branches
echo "<h5 class='mb-3'>## getFeatureBranches(projects)</h5>\n";
$projects = array_keys($projectsNames);
$projects_FB=getFeatureBranches($projects);
echo debug_var_toggle($projects_FB);
echo "<hr class='my-4' />\n";

// Translation Branches
echo "<h5 class='mb-3'>## getTranslationBranches(projects)</h5>\n";
$projects_TB=getTranslationBranches($projects);
echo "<ul class='list-unstyled ms-3 mb-3'>\n";
foreach ($projects_TB as $project_key => $project_TB) {
  echo "<li class='mb-1'><i class='fas fa-code-branch text-info me-2'></i>$project_key</li>\n";
}
echo "</ul>\n";
echo debug_var_toggle($projects_TB);
echo "<hr class='my-4' />\n";

// Acceptance Branches
echo "<h5 class='mb-3'>## getAcceptanceBranches()</h5>\n";
$projects_AB=getAcceptanceBranches();
echo "<ul class='list-unstyled ms-3 mb-3'>\n";
foreach ($projects_AB as $project_AB) {
  echo "<li class='mb-1'><i class='fas fa-check-circle text-success me-2'></i>$project_AB</li>\n";
}
echo "</ul>\n";
echo debug_var_toggle($projects_AB);

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