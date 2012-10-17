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
//print each file name
$vhosts = getDirectoryList($_SERVER['ADT_DATA']."/conf/adt/");
$list = array();
$now = new DateTime();
foreach( $vhosts as $vhost) {
  // Parse deployment descriptor
  $descriptor_array = parse_ini_file($_SERVER['ADT_DATA']."/conf/adt/".$vhost);
  if($descriptor_array['ARTIFACT_DATE']){
    $artifact_age = DateTime::createFromFormat('Ymd.His',$descriptor_array['ARTIFACT_DATE'])->diff($now,true);
    if($artifact_age->days)
      $descriptor_array['ARTIFACT_AGE_STRING'] = $artifact_age->format('%a day(s) ago');
    else if($artifact_age->h > 0)
      $descriptor_array['ARTIFACT_AGE_STRING'] = $artifact_age->format('%h hour(s) ago');
    else
      $descriptor_array['ARTIFACT_AGE_STRING'] = $artifact_age->format('%i minute(s) ago');
    if($artifact_age->days > 5 )
      $descriptor_array['ARTIFACT_AGE_CLASS'] = "red";
    else if($artifact_age->days > 2 )
      $descriptor_array['ARTIFACT_AGE_CLASS'] = "orange";
    else
      $descriptor_array['ARTIFACT_AGE_CLASS'] = "green";      
  } else {
    $descriptor_array['ARTIFACT_AGE_STRING'] = "Unknown";
    $descriptor_array['ARTIFACT_AGE_CLASS'] = "black";
  }
  $deployment_age = DateTime::createFromFormat('Ymd.His',$descriptor_array['DEPLOYMENT_DATE'])->diff($now,true);
  if($deployment_age->days)
    $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%a day(s) ago');
  else if($deployment_age->h > 0)
    $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%h hour(s) ago');
  else
    $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%i minute(s) ago');  
  // Logs URLs
  $scheme = ((!empty($_SERVER['HTTPS'])) && ($_SERVER['HTTPS'] != 'off')) ? "https" : "http";
  
  $descriptor_array['DEPLOYMENT_LOG_APPSRV_URL'] = $scheme."://".$_SERVER['SERVER_NAME']."/logs.php?file=".$descriptor_array['DEPLOYMENT_LOG_PATH'] ;
  $descriptor_array['DEPLOYMENT_LOG_APACHE_URL'] = $scheme."://".$_SERVER['SERVER_NAME']."/logs.php?file=".$_SERVER['ADT_DATA']."/var/log/apache2/".$descriptor_array['PRODUCT_NAME']."-".$descriptor_array['PRODUCT_VERSION'].".".$_SERVER['SERVER_NAME']."-access.log";
  $descriptor_array['DEPLOYMENT_AWSTATS_URL'] = $scheme."://".$_SERVER['SERVER_NAME']."/stats/awstats.pl?config=".$descriptor_array['PRODUCT_NAME']."-".$descriptor_array['PRODUCT_VERSION'].".".$_SERVER['SERVER_NAME'];
  // status
  if (file_exists ($descriptor_array['DEPLOYMENT_PID_FILE']) && processIsRunning(file_get_contents ($descriptor_array['DEPLOYMENT_PID_FILE'])))
    $descriptor_array['DEPLOYMENT_STATUS']="Up";
  else
    $descriptor_array['DEPLOYMENT_STATUS']="Down";
	// Acceptance process state 	
	$descriptor_array['ACCEPTANCE_STATE']="Implementing";
	// Specification Link
	$descriptor_array['SPECIFICATION_LINK']="http://int.exoplatform.org/portal/intranet/wiki/group/spaces/engineering/Home";
	// Add it in the list
	if(empty($descriptor_array['PLF_BRANCH']))
		$list['UNKNOWN'][] = $descriptor_array;
	else
    $list[$descriptor_array['PLF_BRANCH']][] = $descriptor_array;
} 
// Display the list in JSON
echo json_encode($list);
?>