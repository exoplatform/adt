<?php
require_once(dirname(__FILE__) . '/PHPGit/Repository.php');

date_default_timezone_set('UTC');

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
  // All feature branches must be on the origin (see bug: SWF-2520)
  return strpos($branch, "origin/feature/") !== false;
}

function isTranslation($branch)
{
  //echo "isTranslation: $branch : " . (strpos($branch, "translation")===false ? "FALSE":strpos($branch, "translation")) . " / " . (strpos($branch, "origin/integration") === false ? "FALSE" : strpos($branch, "origin/integration")). "<br />\n";
  return strpos($branch, "translation") !== false && strpos($branch, "origin/integration") !== false;
}

function cmpPLFBranches($a, $b)
{
  // Branches are A.B.x or UNKNOWN
  if ($a === 'UNKNOWN') {
    return -strcasecmp('000', $b);
  } else if ($b === 'UNKNOWN') {
    return -strcasecmp($a, '000');
  } else
    return -strcasecmp($a, $b);
}

function cmpInstances($a, $b)
{
  return strcmp($a->PRODUCT_VERSION, $b->PRODUCT_VERSION);
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
      usort($result[$key], 'cmpInstances');
    };
    next($values);
  }
  uksort($result, 'cmpPLFBranches');
  return $result;
}

function getDirectoryList($directory)
{
  // create an array to hold directory list
  $results = array();
  // create a handler for the directory
  $handler = opendir($directory) or die($directory . " doesn't exist");
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

/*
 * Get the list of all repositories
 */
function getRepositories()
{
  $repositories = apc_fetch('repositories');

  if (empty($features)) {
    $repositories = array(
        "platform-ui" => "PLF UI",
        "commons" => "Commons",
        "ecms" => "ECMS",
        "social" => "Social",
        "wiki" => "Wiki",
        "forum" => "Forum",
        "calendar" => "Calendar",
        "integration" => "Integration",
        "platform" => "Platform",
        "platform-public-distributions" => "PLF Public Dist",
        "platform-private-distributions" => "PLF Private Dist");
    apc_store('repositories', $repositories);
  }
  return $repositories;
}

function getFeatureBranches($projects)
{
  $features = apc_fetch('features');

  if (empty($features)) {
    $features = array();
    foreach ($projects as $project) {
      $repoObject = new PHPGit_Repository(getenv('ADT_DATA') . "/sources/" . $project . ".git");
      $branches = array_filter(preg_replace('/.*\/feature\//', '',
                                            array_filter(explode("\n", $repoObject->git('branch -r')), 'isFeature')));
      foreach ($branches as $branch) {
        $fetch_url = $repoObject->git('config --get remote.origin.url');
        if (preg_match("/git@github\.com:(.*)\/(.*)\.git/", $fetch_url, $matches)) {
          $github_org = $matches[1];
          $github_repo = $matches[2];
        }
        $features[$branch][$project]['http_url'] = "https://github.com/" . $github_org . "/" . $github_repo . "/tree/feature/" . $branch;
        $behind_commits_logs = $repoObject->git("log origin/feature/" . $branch . "..origin/develop --oneline");
        if (empty($behind_commits_logs))
          $features[$branch][$project]['behind_commits'] = 0;
        else
          $features[$branch][$project]['behind_commits'] = count(explode("\n", $behind_commits_logs));
        $ahead_commits_logs = $repoObject->git("log origin/develop..origin/feature/" . $branch . " --oneline");
        if (empty($ahead_commits_logs))
          $features[$branch][$project]['ahead_commits'] = 0;
        else
          $features[$branch][$project]['ahead_commits'] = count(explode("\n", $ahead_commits_logs));
      }
    }
    uksort($features, 'strcasecmp');
    // Feature branches will be cached for 5 min
    apc_store('features', $features, 300);
  }
  return $features;
}

function getTranslationBranches($projects)
{
  $features = apc_fetch('translation');

  if (empty($features)) {
    $features = array();
    foreach ($projects as $project) {
      $repoObject = new PHPGit_Repository(getenv('ADT_DATA') . "/sources/" . $project . ".git");
      $branches = array_filter(preg_replace('/.*\/integration\//', '',
                                            array_filter(explode("\n", $repoObject->git('branch -r')), 'isTranslation')));
                                            //print "<pre>";
                                            //print_r($branches);
                                            //print "</pre>";
      foreach ($branches as $branch) {
        $fetch_url = $repoObject->git('config --get remote.origin.url');
        if (preg_match("/git@github\.com:(.*)\/(.*)\.git/", $fetch_url, $matches)) {
          $github_org = $matches[1];
          $github_repo = $matches[2];
        }
        $features[$branch][$project]['http_url'] = "https://github.com/" . $github_org . "/" . $github_repo . "/tree/integration/" . $branch;
        $behind_commits_logs = $repoObject->git("log origin/integration/" . $branch . "..origin/develop --oneline");
        if (empty($behind_commits_logs))
          $features[$branch][$project]['behind_commits'] = 0;
        else
          $features[$branch][$project]['behind_commits'] = count(explode("\n", $behind_commits_logs));
        $ahead_commits_logs = $repoObject->git("log origin/develop..origin/integration/" . $branch . " --oneline");
        if (empty($ahead_commits_logs))
          $features[$branch][$project]['ahead_commits'] = 0;
        else
          $features[$branch][$project]['ahead_commits'] = count(explode("\n", $ahead_commits_logs));
      }
    }
    uksort($features, 'strcasecmp');
    // Translation branches will be cached for 5 min
    apc_store('translation', $features, 300);
  }
  return $features;
}

function getLocalAcceptanceInstances()
{
  $instances = apc_fetch('local_instances');

  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $instances = array();
    $vhosts = getDirectoryList(getenv('ADT_DATA') . "/conf/adt/");
    $now = new DateTime();
    foreach ($vhosts as $vhost) {
      // Parse deployment descriptor
      $descriptor_array = parse_ini_file(getenv('ADT_DATA') . "/conf/adt/" . $vhost);
      $matches = array();
      if (preg_match("/([^\-]*)\-(.*\-.*)\-SNAPSHOT/", $descriptor_array['PRODUCT_VERSION'], $matches)) {
        $descriptor_array['BASE_VERSION'] = $matches[1];
        $descriptor_array['BRANCH_NAME'] = $matches[2];
      } elseif (preg_match("/(.*)\-SNAPSHOT/", $descriptor_array['PRODUCT_VERSION'], $matches)) {
        $descriptor_array['BASE_VERSION'] = $matches[1];
        $descriptor_array['BRANCH_NAME'] = "";
      } else {
        $descriptor_array['BASE_VERSION'] = $descriptor_array['PRODUCT_VERSION'];
        $descriptor_array['BRANCH_NAME'] = "";
      }
      // Instance note
      if (file_exists(getenv('ADT_DATA') . "/conf/instances/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".note"))
        $descriptor_array['INSTANCE_NOTE'] = file_get_contents(getenv('ADT_DATA') . "/conf/instances/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".note");

      if ($descriptor_array['ARTIFACT_DATE']) {
        $artifact_age = DateTime::createFromFormat('Ymd.His', $descriptor_array['ARTIFACT_DATE'])->diff($now, true);
        if ($artifact_age->days)
          $descriptor_array['ARTIFACT_AGE_STRING'] = $artifact_age->format('%a day(s) ago');
        else if ($artifact_age->h > 0)
          $descriptor_array['ARTIFACT_AGE_STRING'] = $artifact_age->format('%h hour(s) ago');
        else
          $descriptor_array['ARTIFACT_AGE_STRING'] = $artifact_age->format('%i minute(s) ago');
        if ($artifact_age->days > 5)
          $descriptor_array['ARTIFACT_AGE_CLASS'] = "red";
        else if ($artifact_age->days > 2)
          $descriptor_array['ARTIFACT_AGE_CLASS'] = "orange";
        else
          $descriptor_array['ARTIFACT_AGE_CLASS'] = "green";
      } else {
        $descriptor_array['ARTIFACT_AGE_STRING'] = "Unknown";
        $descriptor_array['ARTIFACT_AGE_CLASS'] = "black";
      }
      $deployment_age = DateTime::createFromFormat('Ymd.His', $descriptor_array['DEPLOYMENT_DATE'])->diff($now, true);
      if ($deployment_age->days)
        $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%a day(s) ago');
      else if ($deployment_age->h > 0)
        $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%h hour(s) ago');
      else
        $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%i minute(s) ago');
      // Logs URLs
      $scheme = ((!empty($_SERVER['HTTPS'])) && ($_SERVER['HTTPS'] != 'off')) ? "https" : "http";

      $descriptor_array['DEPLOYMENT_LOG_APPSRV_URL'] = $scheme . "://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'] . "/logs.php?file=" . $descriptor_array['DEPLOYMENT_LOG_PATH'];
      $descriptor_array['DEPLOYMENT_LOG_APACHE_URL'] = $scheme . "://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'] . "/logs.php?file=" . getenv('ADT_DATA') . "/var/log/apache2/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . "-access.log";
      $descriptor_array['DEPLOYMENT_AWSTATS_URL'] = $scheme . "://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'] . "/stats/awstats.pl?config=" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'];
      // database informations
      if ( $descriptor_array['DEPLOYMENT_DATABASE_ENABLED'] == false || empty($descriptor_array['DEPLOYMENT_DATABASE_TYPE']) ) {
        $descriptor_array['DATABASE'] = "none";
      } elseif ( $descriptor_array['DEPLOYMENT_DATABASE_TYPE'] == 'MYSQL' ) {
        $descriptor_array['DATABASE'] = "mysql:5.5";
      } elseif ( stripos($descriptor_array['DEPLOYMENT_DATABASE_TYPE'], "docker") !== false ) {
        $descriptor_array['DATABASE'] = strtolower($descriptor_array['DEPLOYMENT_DATABASE_TYPE']) . ":" . $descriptor_array['DEPLOYMENT_DATABASE_VERSION'];
      }
      // status
      if (file_exists($descriptor_array['DEPLOYMENT_PID_FILE']) && processIsRunning(file_get_contents($descriptor_array['DEPLOYMENT_PID_FILE'])))
        $descriptor_array['DEPLOYMENT_STATUS'] = "Up";
      else
        $descriptor_array['DEPLOYMENT_STATUS'] = "Down";
      // Acceptance process state
      if (file_exists(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".status"))
        $descriptor_array['ACCEPTANCE_STATE'] = file_get_contents(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".status");
      else
        $descriptor_array['ACCEPTANCE_STATE'] = "Implementing";
      // Specification Link
      if (file_exists(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".spec"))
        $descriptor_array['SPECIFICATIONS_LINK'] = file_get_contents(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".spec");
      else
        $descriptor_array['SPECIFICATIONS_LINK'] = "";
      // Issue Link
      if (file_exists(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".issue"))
        $descriptor_array['ISSUE_NUM'] = file_get_contents(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".issue");
      else
        $descriptor_array['ISSUE_NUM'] = "";
      // SCM BRANCH
      if (file_exists(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".branch"))
        $descriptor_array['SCM_BRANCH'] = file_get_contents(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".branch");
      else
        $descriptor_array['SCM_BRANCH'] = "";
      // Branch name
      if (file_exists(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".desc"))
        $descriptor_array['BRANCH_DESC'] = file_get_contents(getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . ".desc");
      else
        $descriptor_array['BRANCH_DESC'] = $descriptor_array['BRANCH_NAME'];
      // Server scheme where is deployed the instance
      $descriptor_array['ACCEPTANCE_SCHEME'] = $scheme;
      // Server hostname where is deployed the instance
      $descriptor_array['ACCEPTANCE_HOST'] = $_SERVER['SERVER_NAME'];
      // Server port where is deployed the instance
      $descriptor_array['ACCEPTANCE_PORT'] = $_SERVER['SERVER_PORT'];
      // Apache version where is deployed the instance
      $descriptor_array['ACCEPTANCE_APACHE_VERSION'] = getenv('ADT_APACHE_VERSION');
      $descriptor_array['ACCEPTANCE_APACHE_VERSION_MINOR'] = getenv('ADT_APACHE_VERSION_MINOR');
      // Add it in the list
      if (empty($descriptor_array['PLF_BRANCH']))
        $instances['UNKNOWN'][] = $descriptor_array;
      else
        $instances[$descriptor_array['PLF_BRANCH']][] = $descriptor_array;
    }
    // Instances will be cached for 2 min
    apc_store('local_instances', $instances, 120);
  }
  return $instances;
}

function getGlobalAcceptanceInstances()
{
  $instances = apc_fetch('all_instances');

  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $instances = array();
    if (getenv('ADT_DEV_MODE')) {
      // Emulate decode/encode with json because they are converting array into objects
      // TBD : Cleanup JSON decode/encode and array/objects
      $instances = json_decode(json_encode(getLocalAcceptanceInstances()));
    } else {
      $servers = explode(",", getenv('ACCEPTANCE_SERVERS'));
      foreach ($servers as $server) {
        $instances = append_data($server . '/rest/local-instances.php', $instances);
      }
    }
    // Instances will be cached for 2 min
    apc_store('all_instances', $instances, 120);
  }
  return $instances;
}

function getAcceptanceBranches()
{
  $branches = apc_fetch('acceptance_branches');

  if (empty($branches) || getenv('ADT_DEV_MODE')) {
    $branches = array();
    foreach (getGlobalAcceptanceInstances() as $descriptor_arrays) {
      foreach ($descriptor_arrays as $descriptor_array) {
        if (!empty($descriptor_array->SCM_BRANCH)) {
          $branches[] = $descriptor_array->SCM_BRANCH;
        }
      }
    }
    // Instances will be cached for 2 min
    apc_store('acceptance_branches', $branches, 120);
  }
  return $branches;
}

function clearCaches()
{
  apc_delete("features");
  apc_delete("repositories");
  apc_delete("local_instances");
  apc_delete("all_instances");
  apc_delete("acceptance_branches");
}

function checkCaches()
{
  if (array_key_exists('clearCaches', $_GET)) {
    clearCaches();
    header("Location: " . str_replace("?clearCaches=true", "", currentPageURL())); /* Redirect browser */
    /* Make sure that code below does not get executed when we redirect. */
    exit;
  }
}

?>
