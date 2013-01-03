<?php
require_once(dirname(__FILE__) . '/PHPGit/Repository.php');

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

function sortProjects($a, $b)
{
    // Default projects order
    $i = 0;
    $projectsOrder["commons"] = $i++;
    $projectsOrder["ecms"] = $i++;
    $projectsOrder["social"] = $i++;
    $projectsOrder["forum"] = $i++;
    $projectsOrder["wiki"] = $i++;
    $projectsOrder["calendar"] = $i++;
    $projectsOrder["integration"] = $i++;
    $projectsOrder["platform"] = $i++;
    $projectsOrder["platform-tomcat-standalone"] = $i++;

    if ($a == $b) {
        return 0;
    }
    return strcmp($projectsOrder[$a], $projectsOrder[$b]);
}

function getProjects()
{
    //List all repos
    $projects = preg_replace('/\.git/', '', getGitDirectoriesList(getenv('ADT_DATA') . "/sources/"));
    usort($projects, "sortProjects");
    return $projects;
}

function getFeatureBranches($projects)
{
    $features = array();
    foreach ($projects as $project) {
        $repoObject = new PHPGit_Repository(getenv('ADT_DATA') . "/sources/" . $project . ".git");
        $branches = array_filter(preg_replace('/.*\/feature\//', '', array_filter(explode("\n", $repoObject->git('branch -r')), 'isFeature')));
        foreach ($branches as $branch) {
            $fetch_url = $repoObject->git('config --get remote.origin.url');
            if (preg_match("/git:\/\/github\.com\/(.*)\/(.*)\.git/", $fetch_url, $matches)) {
                $github_org = $matches[1];
                $github_repo = $matches[2];
            }
            $features[$branch][$project]['http_url'] = "https://github.com/" . $github_org . "/" . $github_repo . "/tree/feature/" . $branch;
            $behind_commits_logs = $repoObject->git("log origin/feature/" . $branch . "..origin/master --oneline");
            if (empty($behind_commits_logs))
                $features[$branch][$project]['behind_commits'] = 0;
            else
                $features[$branch][$project]['behind_commits'] = count(explode("\n", $behind_commits_logs));
            $ahead_commits_logs = $repoObject->git("log origin/master..origin/feature/" . $branch . " --oneline");
            if (empty($ahead_commits_logs))
                $features[$branch][$project]['ahead_commits'] = 0;
            else
                $features[$branch][$project]['ahead_commits'] = count(explode("\n", $ahead_commits_logs));
        }
    }
    uksort($features, 'strcasecmp');
    return $features;
}

?>
