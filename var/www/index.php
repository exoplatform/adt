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
                <tr><td colspan="8" style="background-color: #363636; color: #FBAD18; font-weight: bold;">
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
                  <?php if( empty($feature_branch) ) { ?>
										<td colspan="2"></td>
  								<?php } else { ?>
	                  <td><?=$feature_branch?><?php if( ! empty($descriptor_array->SPECIFICATIONS_LINK) ) { ?><a rel="tooltip" title="Specifications" href="<?=$descriptor_array->SPECIFICATIONS_LINK?>"  target="_blank">&nbsp;<i class="icon-book"></i></a><?php } ?></td>
										<td><?=$descriptor_array->ACCEPTANCE_STATE?>&nbsp;<a href="#edit-<?=$descriptor_array->PRODUCT_NAME?>-<?=str_replace(".","_",$descriptor_array->PRODUCT_VERSION)?>" data-toggle="modal"><i class="icon-pencil"></i></a></td>										
									<?php } ?>
                  <td class="<?=$descriptor_array->ARTIFACT_AGE_CLASS?>"><?=$descriptor_array->ARTIFACT_AGE_STRING?></td>
                  <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { echo $descriptor_array->DEPLOYMENT_AGE_STRING; } ?></td>
                  <td><?php if( $descriptor_array->DEPLOYMENT_ENABLED ) { ?><a href="<?=$descriptor_array->DEPLOYMENT_LOG_APPSRV_URL?>" rel="tooltip" title="Instance logs" target="_blank"><img src="/images/terminal_tomcat.png" width="32" height="16" alt="instance logs"  class="left" /></a>&nbsp;<a href="<?=$descriptor_array->DEPLOYMENT_LOG_APACHE_URL?>" rel="tooltip" title="apache logs" target="_blank"><img src="/images/terminal_apache.png" width="32" height="16" alt="apache logs"  class="right" /></a>&nbsp;<a href="<?=$descriptor_array->DEPLOYMENT_JMX_URL?>" rel="tooltip" title="jmx monitoring" target="_blank"><img src="/images/action_log.png" alt="JMX url" width="16" height="16" class="center" /></a>&nbsp;<a href="<?=$descriptor_array->DEPLOYMENT_AWSTATS_URL?>" rel="tooltip" title="<?=$descriptor_array->PRODUCT_NAME." ".$descriptor_array->PRODUCT_VERSION?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="<?=$descriptor_array->DEPLOYMENT_URL?> usage statistics" width="16" height="16" class="center" /></a><?php } ?>&nbsp;<a rel="tooltip" title="Download <?=$descriptor_array->ARTIFACT_GROUPID?>:<?=$descriptor_array->ARTIFACT_ARTIFACTID?>:<?=$descriptor_array->ARTIFACT_TIMESTAMP?> from Acceptance" href="<?=$descriptor_array->ARTIFACT_DL_URL?>"><i class="icon-download-alt"></i></a></td>
                </tr>
								<?php if( ! empty($feature_branch) ) { ?>
								<div class="modal hide fade" id="edit-<?=$descriptor_array->PRODUCT_NAME?>-<?=str_replace(".","_",$descriptor_array->PRODUCT_VERSION)?>" tabindex="-1" role="dialog" aria-labelledby="label-<?=$descriptor_array->PRODUCT_NAME?>-<?=$descriptor_array->PRODUCT_VERSION?>" aria-hidden="true">
									<form class="form-horizontal" action="http://<?=$descriptor_array->ACCEPTANCE_SERVER?>/editFeature.php" method="POST">
								  <div class="modal-header">
								    <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
								    <h3 id="label-<?=$descriptor_array->PRODUCT_NAME?>-<?=$descriptor_array->PRODUCT_VERSION?>">Edit Feature Branch</h3>
								  </div>
                  <input type="hidden" name="from" value="http://<?=$_SERVER['SERVER_NAME'] ?>">											
                  <input type="hidden" name="product" value="<?=$descriptor_array->PRODUCT_NAME?>">
                  <input type="hidden" name="version" value="<?=$descriptor_array->PRODUCT_VERSION?>">
                  <input type="hidden" name="server" value="<?=$descriptor_array->ACCEPTANCE_SERVER?>">
								  <div class="modal-body">
									  <div class="control-group">
									    <label class="control-label">Product</label>
									    <div class="controls">
									      <span class="input-xxlarge uneditable-input"><?php if(empty($descriptor_array->PRODUCT_DESCRIPTION)) echo $descriptor_array->PRODUCT_NAME; else echo $descriptor_array->PRODUCT_DESCRIPTION;?></span>
									    </div>
									  </div>
									  <div class="control-group">
									    <label class="control-label">Version</label>
									    <div class="controls">
									      <span class="input-xxlarge uneditable-input"><?=$base_version?></span>
									    </div>
									  </div>
									  <div class="control-group">
									    <label class="control-label">Feature Branch</label>
									    <div class="controls">
									      <span class="input-xxlarge uneditable-input"><?=$feature_branch?></span>
									    </div>
									  </div>
									  <div class="control-group">
									    <label class="control-label" for="specifications">Specifications link</label>
									    <div class="controls">
									      <input class="input-xxlarge" type="text" id="specifications" name="specifications" placeholder="Url" value="<?=$descriptor_array->SPECIFICATIONS_LINK?>">
												<span class="help-block">eXo intranet URL of specifications</span>
									    </div>
									  </div>
									  <div class="control-group">
									    <label class="control-label" for="status">Status</label>
									    <div class="controls" id="status">
												<select name="status">
												  <option <?php if($descriptor_array->ACCEPTANCE_STATE === "Implementing"){echo "selected";}?>>Implementing</option>
												  <option <?php if($descriptor_array->ACCEPTANCE_STATE === "Engineering Review"){echo "selected";}?>>Engineering Review</option>
												  <option <?php if($descriptor_array->ACCEPTANCE_STATE === "QA Review"){echo "selected";}?>>QA Review</option>
												  <option <?php if($descriptor_array->ACCEPTANCE_STATE === "Validated"){echo "selected";}?>>Validated</option>
												  <option <?php if($descriptor_array->ACCEPTANCE_STATE === "Merged"){echo "selected";}?>>Merged</option>
												</select>
												<span class="help-block">Current status of the feature branch</span>
									    </div>
									  </div>
								  </div>
								  <div class="modal-footer">
								    <button class="btn" data-dismiss="modal" aria-hidden="true">Close</button>
								    <button class="btn btn-primary">Save changes</button>
								  </div>
								</form>
								</div>									
                <?php 
							  }
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
