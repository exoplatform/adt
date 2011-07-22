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
  <div class="Header ClearFix"> <a href="#" class="Logo"></a><span class="AddressWeb">acceptance.exoplatform.org</span> </div>
  <div class="TitleForgePages">Acceptance Live Instances</div>
  <div class="ContentCenter ClearFix">
    <div class="BlockAccount">
      <p>These instances are deployed to be used for acceptance tests.<br/>
        They are deployed from latest successful binaries produced by packaging jobs on <a href="https://ci.exoplatform.org">https://ci.exoplatform.org</a></p>
      <table width="100%" align="center" class="FL">
        <thead>
          <tr>
            <th colspan="2">Product</th>
            <th colspan="3">Current deployment</th>
          </tr>
          <tr>
            <th>Name</th>
            <th>Version</th>
            <th>Date</th>
            <th>Artifact</th>
            <th>URL</th>
          </tr>
        </thead>
        <tbody>
          <?php
  function getDirectoryList ($directory) 
  {
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

  //print each file name
  $vhosts = getDirectoryList("/home/swfhudson/data/adt/conf/adt/");
  sort($vhosts);
  foreach( $vhosts as $vhost) {
    // Parse deployment descriptor
    $descriptor_array = parse_ini_file("/home/swfhudson/data/adt/conf/adt/".$vhost);
?>
          <tr>
            <td><?=$descriptor_array['deployment.product']?></td>
            <td><?=$descriptor_array['artifact.version']?></td>
            <td><?=$descriptor_array['deployment.date']?></td>
            <td><a href="<?=$descriptor_array['artifact.url']?>" class="TxtBlue"><img src="/images/ButDownload.gif" width="19" height="19" alt="Download <?=$descriptor_array['artifact.groupid']?>:<?=$descriptor_array['artifact.artifactid']?>:<?=$descriptor_array['artifact.timestamp']?> from Nexus" /> <?=$descriptor_array['artifact.timestamp']?>
            </a></td>
            <td><a href="<?=$descriptor_array['deployment.url']?>" class="TxtBlue">
              <?=$descriptor_array['deployment.url']?>
              </a> [<a href="<?=$descriptor_array['deployment.logs']?>" class="TxtOrange">logs</a>]</td>
          </tr>
          <?php 
		  } 
		  ?>
        </tbody>
      </table>
    </div>
  </div>
  <div class="Footer">eXo Platform SAS</div>
</div>
</body>
</html>
