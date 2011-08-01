<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<title>Acceptance Live Instances</title>
<link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
<link href="/style.css" media="screen" rel="stylesheet" type="text/css"/>
</head>
<body>
<div class="UIForgePages">
  <div class="Header ClearFix"> <a href="/" class="Logo"></a><span class="AddressWeb">acceptance.exoplatform.org</span> </div>
  <div class="MainContent">
    <div class="Ribbon">Beta !</div>
    <div class="TitleForgePages">Acceptance Live Instances</div>
    <div>
      <div>
        <p>These instances are deployed to be used for acceptance tests.<br/>
          They are deployed from latest  binaries produced by packaging jobs on <a href="https://ci.exoplatform.org">https://ci.exoplatform.org</a></p>
        <p>Each instance can be accessed using JMX with the given URL and these credentials : <span class="TxtBoldContact">acceptanceMonitor</span> / <span class="TxtBoldContact">monitorAcceptance!</span></p>
        <p>&nbsp;</p>
        <table class="center">
          <thead>
            <tr>
              <th colspan="2">Product</th>
              <th colspan="7">Current deployment</th>
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
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <?php
          function getDirectoryList ($directory) {
            // create an array to hold directory list
            $results = array();
            // create a handler for the directory
            $handler = opendir($directory);
            // open directory and walk through the filenames
            while ($file = readdir($handler)) {
              // if file isn't this directory or its parent, add it to the results
              if ($file != "." && $file != "..") {
                $results[] = $file;
              }
            }
            // tidy up: close the handler
            closedir($handler);
            // done!
            return $results;
          }
          function processIsRunning ($pid) {
            // create an array to hold the result
            $output = array();
            // execute a ps for the given pid
            exec("ps -p ".$pid, $output);
            // The process is running if there is a row N#1 (N#0 is the header)
            return isset($output[1]);
          }
          function displayDate ($date_as_string) {
            $date = DateTime::createFromFormat('Ymd.His', $date_as_string);
            return $date->format('D d M Y - H:i:s T');
          }
          //print each file name
          $vhosts = getDirectoryList("/home/swfhudson/data/adt/conf/adt/");
          sort($vhosts);
		  $now = new DateTime();
          foreach( $vhosts as $vhost) {
            // Parse deployment descriptor
            $descriptor_array = parse_ini_file("/home/swfhudson/data/adt/conf/adt/".$vhost);
			$artifact_age = DateTime::createFromFormat('Ymd.His',$descriptor_array['ARTIFACT_DATE'])->diff($now,true);
			if($artifact_age->days)
			  $artifact_age_string = $artifact_age->format('%a day(s) ago');
			else if($artifact_age->h > 0)
			  $artifact_age_string = $artifact_age->format('%h hour(s) ago');
			else
			  $artifact_age_string = $artifact_age->format('%i minute(s) ago');
			$deployment_age = DateTime::createFromFormat('Ymd.His',$descriptor_array['DEPLOYMENT_DATE'])->diff($now,true);
			if($deployment_age->days)
			  $deployment_age_string = $deployment_age->format('%a day(s) ago');
			else if($deployment_age->h > 0)
			  $deployment_age_string = $deployment_age->format('%h hour(s) ago');
			else
			  $deployment_age_string = $deployment_age->format('%i minute(s) ago');
          ?>
            <tr onmouseover="this.className='normalActive'" onmouseout="this.className='normal'" class="normal">
              <td><?=strtoupper($descriptor_array['PRODUCT_NAME'])?></td>
              <td><?=$descriptor_array['PRODUCT_VERSION']?></td>
              <td><a href="<?=$descriptor_array['ARTIFACT_URL']?>" class="TxtBlue" title="Download <?=$descriptor_array['ARTIFACT_GROUPID']?>:<?=$descriptor_array['ARTIFACT_ARTIFACTID']?>:<?=$descriptor_array['ARTIFACT_TIMESTAMP']?> from Nexus"><img class="left" src="/images/ButDownload.gif" alt="Download" width="19" height="19" />&nbsp;
                <?=$descriptor_array['ARTIFACT_TIMESTAMP']?>
              </a></td>
              <td><?=$artifact_age_string?></td>
              <td><?=$deployment_age_string?></td>
              <td><a href="<?=$descriptor_array['DEPLOYMENT_URL']?>" class="TxtBlue" target="_blank" title="Open the instance in a new window">
                <?=$descriptor_array['DEPLOYMENT_URL']?>
              </a></td>
              <td><a href="/logs.php?file=<?=$descriptor_array['DEPLOYMENT_LOG_PATH']?>" class="TxtOrange" title="Instance logs" target="_blank"><img src="/images/terminal.gif" width="16" height="16" alt="instance logs"  class="center" /></a></td>
              <td><a href="<?=$descriptor_array['DEPLOYMENT_JMX_URL']?>" class="TxtOrange" title="jmx monitoring" target="_blank"><img src="/images/action_log.png" alt="JMX url" width="16" height="16" class="center" /></a></td>
              <?php
            if (file_exists ($descriptor_array['DEPLOYMENT_PID_FILE']) && processIsRunning(file_get_contents ($descriptor_array['DEPLOYMENT_PID_FILE'])))
              $status="<img width=\"16\" height=\"16\" src=\"/images/green_ball.png\" alt=\"Up\"  class=\"left\"/>&nbsp;Up";
            else
              $status="<img width=\"16\" height=\"16\" src=\"/images/red_ball.png\" alt=\"Down\"  class=\"left\"/>&nbsp;Down !";
            ?>
              <td><?=$status?></td>
            </tr>
            <?php 
          } 
          ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
  <div class="Footer">eXo Platform SAS</div>
</div>
</body>
</html>
