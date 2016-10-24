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
          <li><a href="/features.php">Features</a></li>
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

my_print_r(apc_cache_info('user'));
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
