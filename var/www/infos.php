<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<title>Acceptance Live Instances</title>
<link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
<link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/css/bootstrap-combined.min.css" type="text/css" rel="stylesheet" media="all">
<link href="//netdna.bootstrapcdn.com/bootswatch/2.1.0/spacelab/bootstrap.min.css" type="text/css" rel="stylesheet" media="all">
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
            <table class="table table-striped table-bordered table-hover">
              <thead>
                <tr>
                  <th colspan="3">Product</th>
                  <th colspan="2">Deployment</th>
                  <th colspan="5">Ports</th>
                </tr>
                <tr>
                  <th>Name</th>
                  <th>Snapshot Version</th>
                  <th>Feature Branch</th>
                  <th>Server</th>
                  <th>Status</th>
                  <th>HTTP</th>
                  <th>AJP</th>
                  <th>Shutdown</th>                                    
                  <th>JMX RMI Registration</th>
                  <th>JMX RMI Server</th>
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
              $merged_list = append_data('http://acceptance3.exoplatform.org/list.php',$merged_list);
              $descriptor_arrays = array();
              while ($tmp_array = current($merged_list)) {
                $descriptor_arrays = array_merge($descriptor_arrays,$tmp_array);
                next($merged_list);
              }
              function cmp($a, $b)
              {
                return strcmp($a->DEPLOYMENT_HTTP_PORT, $b->DEPLOYMENT_HTTP_PORT);
              }
              usort($descriptor_arrays, "cmp");
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
                  <td><?php if(empty($descriptor_array->PRODUCT_DESCRIPTION)) echo $descriptor_array->PRODUCT_NAME; else echo $descriptor_array->PRODUCT_DESCRIPTION;?></td>
                  <td><?=$base_version?></td>
                  <td><?=$feature_branch?></td>
                  <td style="font-weight:bold;" class='<?php if ( $descriptor_array->ACCEPTANCE_SERVER === "acceptance.exoplatform.org" ) echo "blue"; else echo "green";?>'><?=$descriptor_array->ACCEPTANCE_SERVER?></td>
                  <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { echo $status; } ?></td>
                  <td><?=$descriptor_array->DEPLOYMENT_HTTP_PORT?></td>                  
                  <td><?=$descriptor_array->DEPLOYMENT_AJP_PORT?></td>                  
                  <td><?=$descriptor_array->DEPLOYMENT_SHUTDOWN_PORT?></td>                  
                  <td><?=$descriptor_array->DEPLOYMENT_RMI_REG_PORT?></td>                  
                  <td><?=$descriptor_array->DEPLOYMENT_RMI_SRV_PORT?></td>                  
                </tr>
                <?php 
              }
              ?>
              </tbody>
            </table>
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
