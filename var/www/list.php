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
foreach( $vhosts as $vhost) {
  // Parse deployment descriptor
  $list[] = parse_ini_file($_SERVER['ADT_DATA']."/conf/adt/".$vhost);
} 
echo json_encode($list);
?>