<?php

// this method will return the current page full url
function currentPageURL()
{
    $pageURL = 'http';
    if (array_key_exists('HTTPS', $_SERVER) && $_SERVER['HTTPS'] == 'on') {
        $pageURL .= 's';
    }
    $pageURL .= '://';
    if ($_SERVER['SERVER_PORT'] != '80') {
        $pageURL .= $_SERVER['SERVER_NAME'] . ':' . $_SERVER['SERVER_PORT'] . $_SERVER['REQUEST_URI'];
    } else {
        $pageURL .= $_SERVER['SERVER_NAME'] . $_SERVER['REQUEST_URI'];
    }
    return $pageURL;
}
function sortProjects($a, $b)
{
    global $project;
    if ($a == $b) {
        return 0;
    }
    return strcmp($project[substr($a, 0, -4)], $project[substr($b, 0, -4)]);
}
function getGitDirectoriesList($directory)
{
    // create an array to hold directory list
    $results = array();
    // create a handler for the directory
    $handler = opendir($directory);
    // open directory and walk through the filenames
    while ($file = readdir($handler)) {
        // if file isn't this directory or its parent, add it to the results
        if ($file != "." && $file != ".." && strpos($file, ".git")) {
            $results[] = $file;
        }
    }
    // tidy up: close the handler
    closedir($handler);
    // done!
    return $results;
}
function isFeature($branch)
{
    return strpos($branch, "/feature/");
}

function append_data($url, $data)
{
    $result = $data;
    $values = (array)json_decode(file_get_contents($url));
    while ($entry = current($values)) {
        $key = key($values);
        if (!array_key_exists($key, $data)) {
            $result[$key] = $entry;
        } else {
            $result[$key] = array_merge($entry, $data[$key]);
        }
        ;
        next($values);
    }
    return $result;
}

function getDirectoryList($directory)
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

function processIsRunning($pid)
{
    // create an array to hold the result
    $output = array();
    // execute a ps for the given pid
    exec("ps -p " . $pid, $output);
    // The process is running if there is a row N#1 (N#0 is the header)
    return isset($output[1]);
}

?>
