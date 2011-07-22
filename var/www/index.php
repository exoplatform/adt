<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<title>Acceptance Live Instances</title>
<link rel="shortcut icon" type="image/x-icon" href="/exo-static/images/favicon.ico" />
<link href="/exo-static/style.css" media="screen" rel="stylesheet" type="text/css"/>
</head>
<body>
<div class="UIForgePages">
  <div class="Header ClearFix"> <a href="#" class="Logo"></a><span class="AddressWeb">acceptance.exoplatform.org</span> </div>
  <div class="TitleForgePages">Acceptance Live Instances</div>
  <div class="ContentCenter ClearFix">
    <div class="BlockAccount">
      <p>These instances are deployed to be used for acceptance tests.<br/>
        They are deployed from latest successful binaries produced by </p>
      <table>
        <thead>
          <tr>
            <th>Product</th>
            <th>Version</th>
            <th>Timestamp</th>
            <th>URL</th>
            <th></th>
            <th>Deployment date</th>
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
            <td><?=$descriptor_array['artifact.timestamp']?></td>
            <td><a href="<?=$descriptor_array['deployment.url']?>" class="TxtBlue">
              <?=$descriptor_array['deployment.url']?>
              </a> [<a href="<?=$descriptor_array['deployment.logs']?>" class="TxtOrange">logs</a>]</td>
            <td><a href="<?=$descriptor_array['artifact.url']?>" class="TxtBlue">Download Archive</a></td>
            <td><?=$descriptor_array['deployment.date']?></td>
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
