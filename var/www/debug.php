<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
checkCaches();
?>
<html>
<head>
  <?= pageHeader("debug"); ?>
  <script type="text/javascript">
    $("tr").on("click", function (event) {
      $(this).addClass('highlight').siblings().removeClass('highlight');
    });
    if (window.location.hash.length > 0) {
      $trSelector = "a[name=" + window.location.hash.substring(1, window.location.hash.length) + "]";
      $($trSelector).parents('tr').addClass('highlight').siblings().removeClass('highlight');
    }
  });
  </script>
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

function my_print_r_toggle($html_id, $array) {
  echo"<button type=\"button\" class=\"btn btn-danger\" data-toggle=\"collapse\" data-target=\"#".$html_id."\">details</button>";
  echo "<div id=\"".$html_id."\" class=\"collapse out\">";
  my_print_r ($array);
  echo "</div>\n";
}

function draw_sep($id) {
  echo "<hr id=\"$id\"/>\n";
}

?>

<ul>
  <li><a href="#REPOS">Repositories</a></li>
  <li><a href="#FB">Feature Branches</a></li>
  <li><a href="#TB">Translation Branches</a></li>
  <li><a href="#AB">Acceptance Branches</a></li>
  <li><a href="#INST">Acceptance Instances (Globale)</a></li>
</ul>

<?php

draw_sep("REPOS");
echo "## getRepositories<br />\n";
$projectsNames = getRepositories();
my_print_r_toggle ("REPOS_toggle", $projectsNames);

draw_sep("FB");
echo "## getFeatureBranches(projects)<br />\n";

$projects = array_keys($projectsNames);
$projects_FB=getFeatureBranches($projects);
my_print_r_toggle ("FB_toggle",$projects_FB);

// Translation Branches
draw_sep("TB");
echo "## getTranslationBranches(projects)<br />\n";
$projects_TB=getTranslationBranches($projects);

foreach ($projects_TB as $project_key => $project_TB) {
  echo "$project_key <br />\n";
}
my_print_r_toggle ("TB_toggle",$projects_TB);

// Acceptance Branches
draw_sep("TB");
echo "## getAcceptanceBranches()<br />\n";
$projects_AB=getAcceptanceBranches();

foreach ($projects_AB as $project_AB) {
  echo "$project_AB <br />\n";
}
my_print_r_toggle ("AB_toggle",$projects_AB);


draw_sep("INST");
echo "## getGlobalAcceptanceInstances()<br />\n";
$instances=getGlobalAcceptanceInstances();
foreach ($instances as $category => $instances_array) {
  echo "$category : <br />\n";
  foreach ($instances_array as $instance) {
    echo "&nbsp;&nbsp;&nbsp; $instance->INSTANCE_DESCRIPTION<br />\n";
  }
}
my_print_r_toggle ("INST_toggle",$instances);
?>
</div>
</div>
<!-- /container -->
</div>
</div>
<?php pageFooter(); ?>
</body>
</html>
