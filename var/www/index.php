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
<link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/css/bootstrap-combined.min.css" type="text/css" rel="stylesheet" media="all">
<link href="//netdna.bootstrapcdn.com/bootswatch/2.1.0/spacelab/bootstrap.min.css" type="text/css" rel="stylesheet" media="all">
<link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
<link href="./style.css" media="screen" rel="stylesheet" type="text/css"/>
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
      <div class="container-fluid">
        <a class="brand" href="#"><?=$_SERVER['SERVER_NAME'] ?></a>
      </div>
    </div>
  </div>
  <!-- /navbar -->
  <!-- Main ================================================== -->
  <div id="wrap">
    <div id="main">
      <div class="container-fluid">
        <div class="row-fluid">
          <div class="span12">
		        <legend>Welcome on Acceptance Live Instances !</legend>
		        <p>These instances are deployed to be used for acceptance tests.Terms of usage and others documentations about this service are detailed in our <a href="https://wiki-int.exoplatform.org/x/loONAg">internal wiki</a>.</p>
            <table class="table table-striped table-bordered table-hover">
		          <thead>
		            <tr>
		              <th colspan="2">Product</th>
		              <th colspan="8">Current deployment</th>
		            </tr>
		            <tr>
		              <th>Name</th>
		              <th>Version</th>
		              <th>Artifact</th>
		              <th>Built</th>
		              <th>Deployed</th>
		              <th>URL</th>
		              <th>Logs</th>
		              <th>JMX</th>
		              <th>Stats</th>
		              <th>Status</th>
		            </tr>
		          </thead>
              <tbody>
		            <?php
		          // Get remote file contents, preferring faster cURL if available
		          function remote_get_contents($url)
		          {
		            if (function_exists('curl_get_contents') AND function_exists('curl_init'))
		            {
		              return curl_get_contents($url);
		            }
		            else
		            {
		              // A litte slower, but (usually) gets the job done
		              return file_get_contents($url);
		            }
		          }

		          function curl_get_contents($url)
		          {
		            // Initiate the curl session
		            $ch = curl_init();
		            // Set the URL
		            curl_setopt($ch, CURLOPT_URL, $url);
		            // Removes the headers from the output
		            curl_setopt($ch, CURLOPT_HEADER, 0);
		            // Return the output instead of displaying it directly
		            curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
		            // Execute the curl session
		            $output = curl_exec($ch);
		            // Close the curl session
		            curl_close($ch);
		            // Return the output as a variable
		            return $output;
		          }
		          function append_data($url,$data)
		          {
		            $result=$data;
		            $values=(array)json_decode(remote_get_contents($url));
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
		            <tr><td colspan="10" style="background-color: #363636; color: #FBAD18; font-weight: bold;">
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
		            ?>
		            <tr onmouseover="this.className='normalActive'" onmouseout="this.className='normal'" class="normal">
		              <td><?=strtoupper($descriptor_array->PRODUCT_NAME)?></td>
		              <td><?=$descriptor_array->PRODUCT_VERSION?></td>
		              <td><a href="<?=$descriptor_array->ARTIFACT_DL_URL?>" class="TxtBlue" title="Download <?=$descriptor_array->ARTIFACT_GROUPID?>:<?=$descriptor_array->ARTIFACT_ARTIFACTID?>:<?=$descriptor_array->ARTIFACT_TIMESTAMP?> from Acceptance"><img class="left" src="/images/ButDownload.gif" alt="Download" width="19" height="19" />&nbsp;<?=$descriptor_array->ARTIFACT_TIMESTAMP?></a></td>
		              <td class="<?=$descriptor_array->ARTIFACT_AGE_CLASS?>"><?=$descriptor_array->ARTIFACT_AGE_STRING?></td>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { echo $descriptor_array->DEPLOYMENT_AGE_STRING; } ?></td>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { ?><a href="<?=$descriptor_array->DEPLOYMENT_URL?>" class="TxtBlue" target="_blank" title="Open the instance in a new window"><?=$descriptor_array->DEPLOYMENT_URL?></a><?php } ?></td>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { ?><a href="<?=$descriptor_array->DEPLOYMENT_LOG_APPSRV_URL?>" class="TxtOrange" title="Instance logs" target="_blank"><img src="/images/terminal_tomcat.png" width="32" height="16" alt="instance logs"  class="left" /></a><a href="<?=$descriptor_array->DEPLOYMENT_LOG_APACHE_URL?>" class="TxtOrange" title="apache logs" target="_blank"><img src="/images/terminal_apache.png" width="32" height="16" alt="apache logs"  class="right" /></a><?php } ?></td>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { ?><a href="<?=$descriptor_array->DEPLOYMENT_JMX_URL?>" class="TxtOrange" title="jmx monitoring" target="_blank"><img src="/images/action_log.png" alt="JMX url" width="16" height="16" class="center" /></a><?php } ?></td>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { ?><a href="<?=$descriptor_array->DEPLOYMENT_AWSTATS_URL?>" class="TxtOrange" title="<?=$descriptor_array->DEPLOYMENT_URL?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="<?=$descriptor_array->DEPLOYMENT_URL?> usage statistics" width="16" height="16" class="center" /></a><?php } ?></td>
		              <?php
		            if ($descriptor_array->DEPLOYMENT_STATUS=="Up")
		              $status="<img width=\"16\" height=\"16\" src=\"/images/green_ball.png\" alt=\"Up\"  class=\"left\"/>&nbsp;Up";
		            else
		              $status="<img width=\"16\" height=\"16\" src=\"/images/red_ball.png\" alt=\"Down\"  class=\"left\"/>&nbsp;Down !";
		            ?>
		              <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { echo $status; } ?></td>
		            </tr>
		            <?php 
		          } 
		          next($merged_list);
		          }
		          ?>
              </tbody>
            </table>
		        <p>Each instance can be accessed using JMX with the  URL linked to the monitoring icon and these credentials : <span class="TxtBoldContact">acceptanceMonitor</span> / <span class="TxtBoldContact">monitorAcceptance!</span></p>
		        <p><a href="/stats/awstats.pl?config=<?=$_SERVER['SERVER_NAME'] ?>" class="TxtBlue" title="http://<?=$_SERVER['SERVER_NAME'] ?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="Statistics" width="16" height="16" class="left" />http://<?=$_SERVER['SERVER_NAME'] ?> usage statistics</a></p>								
          </div>
        </div>
      </div>
      <!-- /container -->
    </div>
  </div>
  <!-- Footer ================================================== -->
  <div id="footer">Copyright © 2000-2012. All rights Reserved, eXo Platform SAS.</div>
</body>
</html>
