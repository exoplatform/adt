<!DOCTYPE html>
<?php
/*
 No cache!!
*/
header("Expires: Mon, 26 Jul 1997 05:00:00 GMT"); // Date in the past
header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
// always modified
header("Cache-Control: no-store, no-cache, must-revalidate"); // HTTP/1.1
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache"); // HTTP/1.0
/*
 End of No cache
*/
?>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<title>Acceptance Live Instances</title>
<link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
<link href="./style.css" media="screen" rel="stylesheet" type="text/css"/>
<link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/css/bootstrap-combined.min.css" type="text/css" rel="stylesheet" media="all">
<link href="//netdna.bootstrapcdn.com/bootswatch/2.1.0/spacelab/bootstrap.min.css" type="text/css" rel="stylesheet" media="all">
<script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.1/jquery.min.js" type="text/javascript"></script>
<script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/js/bootstrap.min.js" type="text/javascript"></script>
<script type="text/javascript">
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-1292368-28']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>
</head>
<body>
  <!-- navbar ================================================== -->
  <div id="navbar" class="navbar navbar-fixed-top" data-dropdown="dropdown">
    <div class="navbar-inner">
      <div class="container">
        <a class="brand" href="#"><?=$_SERVER['SERVER_NAME'] ?></a>
      </div>
    </div>
  </div>
  <!-- /navbar -->
  <!-- Main ================================================== -->
  <div id="wrap">
    <div id="main">
      <div class="container">
        <div class="row">
          <div class="span12">
		        <legend>Welcome on Acceptance Live Instances !</legend>
		        <p>These instances are deployed to be used for acceptance tests. Terms of usage and others documentations about this service are detailed in our <a href="https://wiki-int.exoplatform.org/x/loONAg">internal wiki</a>.</p>
            <table class="table table-striped table-bordered table-hover">
		          <thead>
		            <tr>
  		              <th>Status</th>
		              <th>Name</th>
		              <th>Snapshot Version</th>
		              <th>Feature Branch</th>
		              <th>Built</th>
		              <th>Deployed</th>
		              <th>&nbsp;</th>
		            </tr>
		          </thead>
              <tbody>
		            <?php
		          function append_data($url,$data)
		          {
		            $result=$data;
		            $values=(array)json_decode(file_get_contents($url));
		            while ($entry = current($values)) {
									$key=key($values);
		              if(!array_key_exists($key,$data)){
		                $result[$key]=$entry;
		              } else {
		                $result[$key]=array_merge($entry,$data[$key]);
		              };
		              next($values);
		            }
		            return $result;
		          }
		          $merged_list = array();
		          $merged_list = append_data('http://acceptance.exoplatform.org/list.php',$merged_list);
		          $merged_list = append_data('http://acceptance2.exoplatform.org/list.php',$merged_list);                                 
		          while ($descriptor_arrays = current($merged_list)) {
		            ?>
		            <tr><td colspan="7" style="background-color: #363636; color: #FBAD18; font-weight: bold;">
									<?php
								if(key($merged_list) === "4.0.x"){
									echo "Platform ".key($merged_list)." based build (R&D)";
								} elseif(key($merged_list) === "UNKNOWN"){
									echo "Unclassified projects";
								} else {
									echo "Platform ".key($merged_list)." based build (Maintenance)";
							  }
									?>
								</td></tr>
		            <?php
		          foreach( $descriptor_arrays as $descriptor_array) {
		            if ($descriptor_array->DEPLOYMENT_STATUS=="Up")
		              $status="<img width=\"16\" height=\"16\" src=\"/images/green_ball.png\" alt=\"Up\"  class=\"left\"/>&nbsp;Up";
		            else
		              $status="<img width=\"16\" height=\"16\" src=\"/images/red_ball.png\" alt=\"Down\"  class=\"left\"/>&nbsp;Down !";
                    $matches = array();
		            if(preg_match("/([^\-]*)\-(.*\-.*)\-SNAPSHOT/", $descriptor_array->PRODUCT_VERSION, $matches)){
						$base_version=$matches[1];
	                    $feature_branch=$matches[2];
					} elseif (preg_match("/(.*)\-SNAPSHOT/", $descriptor_array->PRODUCT_VERSION, $matches)){
						$base_version=$matches[1];
	                    $feature_branch="";						
					} else {
						$base_version=$descriptor_array->PRODUCT_VERSION;
	                    $feature_branch="";
					}
		            ?>
		            <tr>
  		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { echo $status; } ?></td>
		              <td><?php if(empty($descriptor_array->PRODUCT_DESCRIPTION)) echo $descriptor_array->PRODUCT_NAME; else echo $descriptor_array->PRODUCT_DESCRIPTION;?></td>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { ?><a href="<?=$descriptor_array->DEPLOYMENT_URL?>" target="_blank" rel="tooltip" title="Open the instance in a new window"><i class="icon-home"></i> <?=$base_version?></a><?php } else { ?><?=$base_version?><?php } ?></td>
		              <td><?=$feature_branch?></td>
		              <td class="<?=$descriptor_array->ARTIFACT_AGE_CLASS?>"><?=$descriptor_array->ARTIFACT_AGE_STRING?></td>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { echo $descriptor_array->DEPLOYMENT_AGE_STRING; } ?></td>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { ?><a href="<?=$descriptor_array->DEPLOYMENT_LOG_APPSRV_URL?>" rel="tooltip" title="Instance logs" target="_blank"><img src="/images/terminal_tomcat.png" width="32" height="16" alt="instance logs"  class="left" /></a>&nbsp;<a href="<?=$descriptor_array->DEPLOYMENT_LOG_APACHE_URL?>" rel="tooltip" title="apache logs" target="_blank"><img src="/images/terminal_apache.png" width="32" height="16" alt="apache logs"  class="right" /></a>&nbsp;<a href="<?=$descriptor_array->DEPLOYMENT_JMX_URL?>" rel="tooltip" title="jmx monitoring" target="_blank"><img src="/images/action_log.png" alt="JMX url" width="16" height="16" class="center" /></a>&nbsp;<a href="<?=$descriptor_array->DEPLOYMENT_AWSTATS_URL?>" rel="tooltip" title="<?=$descriptor_array->PRODUCT_DESCRIPTION." ".$descriptor_array->PRODUCT_VERSION?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="<?=$descriptor_array->DEPLOYMENT_URL?> usage statistics" width="16" height="16" class="center" /></a><?php } ?>&nbsp;<a rel="tooltip" title="Download <?=$descriptor_array->ARTIFACT_GROUPID?>:<?=$descriptor_array->ARTIFACT_ARTIFACTID?>:<?=$descriptor_array->ARTIFACT_TIMESTAMP?> from Acceptance" href="<?=$descriptor_array->ARTIFACT_DL_URL?>"><i class="icon-download-alt"></i></a></td>
		            </tr>
		            <?php 
		          } 
		          next($merged_list);
		          }
		          ?>
              </tbody>
            </table>
		        <p>Each instance can be accessed using JMX with the  URL linked to the monitoring icon and these credentials : <strong><code>acceptanceMonitor</code></strong> / <strong><code>monitorAcceptance!</code></strong></p>
		        <p><a href="/stats/awstats.pl?config=<?=$_SERVER['SERVER_NAME'] ?>" title="http://<?=$_SERVER['SERVER_NAME'] ?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="Statistics" width="16" height="16" class="left" />http://<?=$_SERVER['SERVER_NAME'] ?> usage statistics</a></p>								
          </div>
        </div>
      </div>
      <!-- /container -->
    </div>
  </div>
  <!-- Footer ================================================== -->
  <div id="footer">Copyright © 2000-2012. All rights Reserved, eXo Platform SAS.</div>
  <script type="text/javascript">
    $(document).ready(function () {
      $('body').tooltip({ selector:'[rel=tooltip]'});	
      $('body').popover({ selector:'[rel=popover]'});
    });
  </script>
  
</body>
</html>
