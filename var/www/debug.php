<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
checkCaches();
?>
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
  <meta http-equiv="refresh" content="120">
  <title>Acceptance Live Instances</title>
  <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico"/>
  <link href="//netdna.bootstrapcdn.com/bootswatch/2.3.0/spacelab/bootstrap.min.css" rel="stylesheet">
  <link href="//netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css" rel="stylesheet">
  <link href="./style.css" media="screen" rel="stylesheet" type="text/css"/>
  <script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js" type="text/javascript"></script>
  <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js" type="text/javascript"></script>
  <script type="text/javascript">
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-1292368-28']);
  _gaq.push(['_trackPageview']);

  $(document).ready(function () {
    var ga = document.createElement('script');
    ga.type = 'text/javascript';
    ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0];
    s.parentNode.insertBefore(ga, s);
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
  <!-- navbar ================================================== -->
  <div class="navbar navbar-fixed-top">
    <div class="navbar-inner">
      <div class="container-fluid">
        <a class="brand" href="/"><?=$_SERVER['SERVER_NAME'] ?></a>
        <ul class="nav">
          <li><a href="/">Home</a></li>
          <li class="active"><a href="/features.php">Features</a></li>
          <li><a href="/servers.php">Servers</a></li>
        </ul>
      </div>
    </div>
  </div>
  <!-- /navbar -->
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
<!-- Footer ================================================== -->
<div id="footer">Copyright © 2000-2016. All rights Reserved, eXo Platform SAS.</div>
<script type="text/javascript">
$(document).ready(function () {
  $('body').tooltip({ selector: '[rel=tooltip]'});
});
</script>
</body>
</html>
