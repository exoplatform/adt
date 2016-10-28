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
        "gatein-portal" => "GateIn",
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
        // Add link to GitHub diff URL
        $features[$branch][$project]['http_url_behind'] = "https://github.com/" . $github_org . "/" . $github_repo . "/compare/feature/" . $branch."...develop";
        $features[$branch][$project]['http_url_ahead'] = "https://github.com/" . $github_org . "/" . $github_repo . "/compare/develop" ."...feature/".$branch;
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
        // Add link to GitHub diff URL
        $features[$branch][$project]['http_url_behind'] = "https://github.com/" . $github_org . "/" . $github_repo . "/compare/integration/" . $branch."...develop";
        $features[$branch][$project]['http_url_ahead'] = "https://github.com/" . $github_org . "/" . $github_repo . "/compare/develop" ."...integration/".$branch;
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

      if ( empty($descriptor_array['INSTANCE_KEY']) ) {
        $descriptor_array['INSTANCE_KEY'] = $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'];
      }

      // Instance note
      if (file_exists(getenv('ADT_DATA') . "/conf/instances/" . $descriptor_array['INSTANCE_KEY'] . ".note"))
        $descriptor_array['INSTANCE_NOTE'] = file_get_contents(getenv('ADT_DATA') . "/conf/instances/" . $descriptor_array['INSTANCE_KEY'] . ".note");

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
      if (!empty($descriptor_array['DEPLOYMENT_DATE'])) {
          $deployment_age = DateTime::createFromFormat('Ymd.His', $descriptor_array['DEPLOYMENT_DATE'])->diff($now, true);
          if ($deployment_age->days)
              $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%a day(s) ago');
          else if ($deployment_age->h > 0)
              $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%h hour(s) ago');
          else
              $descriptor_array['DEPLOYMENT_AGE_STRING'] = $deployment_age->format('%i minute(s) ago');
      } else {
          $descriptor_array['DEPLOYMENT_AGE_STRING'] = "-NC-";
      }
      // Logs URLs
      $scheme = ((!empty($_SERVER['HTTPS'])) && ($_SERVER['HTTPS'] != 'off')) ? "https" : "http";

      $descriptor_array['DEPLOYMENT_LOG_APPSRV_URL'] = $scheme . "://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'] . "/logs.php?type=instance&file=" . $descriptor_array['DEPLOYMENT_LOG_PATH'];
      $descriptor_array['DEPLOYMENT_LOG_APACHE_URL'] = $scheme . "://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'] . "/logs.php?type=apache&file=" . getenv('ADT_DATA') . "/var/log/apache2/" . $descriptor_array['PRODUCT_NAME'] . "-" . $descriptor_array['PRODUCT_VERSION'] . "." . $_SERVER['SERVER_NAME'] . "-access.log";
      $descriptor_array['DEPLOYMENT_AWSTATS_URL'] = $scheme . "://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'] . "/stats/awstats.pl?config=" . $descriptor_array['INSTANCE_KEY'] . "." . $_SERVER['SERVER_NAME'];
      // database informations
      if ( $descriptor_array['DEPLOYMENT_DATABASE_ENABLED'] == false || empty($descriptor_array['DEPLOYMENT_DATABASE_TYPE']) ) {
        $descriptor_array['DATABASE'] = "none";
      } elseif ( $descriptor_array['DEPLOYMENT_DATABASE_TYPE'] == 'MYSQL' ) {
        $descriptor_array['DATABASE'] = "mysql:5.5";
      } elseif ( stripos($descriptor_array['DEPLOYMENT_DATABASE_TYPE'], "docker") !== false ) {
        $descriptor_array['DATABASE'] = str_replace("docker_", "", strtolower($descriptor_array['DEPLOYMENT_DATABASE_TYPE'])) . ":" . $descriptor_array['DEPLOYMENT_DATABASE_VERSION'];
      }
      // status
      if (file_exists($descriptor_array['DEPLOYMENT_PID_FILE']) && processIsRunning(file_get_contents($descriptor_array['DEPLOYMENT_PID_FILE'])))
        $descriptor_array['DEPLOYMENT_STATUS'] = "Up";
      else
        $descriptor_array['DEPLOYMENT_STATUS'] = "Down";

      // Deployment Labels
      if (empty($descriptor_array['DEPLOYMENT_LABELS'])) {
        $descriptor_array['DEPLOYMENT_LABELS']=array();
      } else {
        $descriptor_array['DEPLOYMENT_LABELS']=explode(',',$descriptor_array['DEPLOYMENT_LABELS']);
      }

      $file_base = getenv('ADT_DATA') . "/conf/features/" . $descriptor_array['INSTANCE_KEY'];
      $file_spec = $file_base  . ".spec";
      $file_status = $file_base . ".status";
      $file_issue = $file_base . ".issue";
      $file_desc = $file_base . ".desc";
      $file_branch = $file_base . ".branch";

      // Acceptance process state
      if (file_exists($file_status))
        $descriptor_array['ACCEPTANCE_STATE'] = file_get_contents($file_status);
      else
        $descriptor_array['ACCEPTANCE_STATE'] = "Implementing";
      // Specification Link
      if (file_exists($file_spec))
        $descriptor_array['SPECIFICATIONS_LINK'] = file_get_contents($file_spec);
      else
        $descriptor_array['SPECIFICATIONS_LINK'] = "";
      // Issue Link
      if (file_exists($file_issue))
        $descriptor_array['ISSUE_NUM'] = file_get_contents($file_issue);
      else
        $descriptor_array['ISSUE_NUM'] = "";
      // SCM BRANCH
      if (file_exists($file_branch))
        $descriptor_array['SCM_BRANCH'] = file_get_contents($file_branch);
      else
        $descriptor_array['SCM_BRANCH'] = "";
      // Branch name
      if (file_exists($file_desc))
        $descriptor_array['BRANCH_DESC'] = file_get_contents($file_desc);
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

/**
 * Get all the deployment regardless of the usage
 *
 * @return array
 */
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

/**
 * Get all the deployment for developer usage only (remove sales environment)
 *
 * @return array
 */
function getGlobalDevInstances() {
  $instances = apc_fetch('dev_instances');
  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $all_instances=getGlobalAcceptanceInstances();
    foreach ($all_instances as $plf_branch => $descriptor_arrays) {
      $filtered_instances=filterInstancesWithoutLabels($descriptor_arrays, array('sales','qa', 'company', 'doc', 'translation'));
      if (count($filtered_instances)>0) {
        $instances[$plf_branch]=$filtered_instances;
      }
    }
    if (count($instances)==0) {
      $instances[]=array();
    }
    // Instances will be cached for 2 min
    apc_store('dev_instances', $instances, 120);
  }
  return $instances;
}

/**
 * Get all the personnal deployments for Sales Team only
 *
 * @return array
 */
function getGlobalSalesUserInstances()
{
  $instances = apc_fetch('sales_user_instances');
  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $all_instances=getGlobalAcceptanceInstances();
    foreach ($all_instances as $plf_branch => $descriptor_arrays) {
      $filtered_instances=filterInstancesWithLabels($descriptor_arrays, array("sales","user"), true);
      if (count($filtered_instances)>0) {
        $instances[$plf_branch]=$filtered_instances;
      }
    }
    if (count($instances)==0) {
      $instances[]=array();
    }
    // Instances will be cached for 2 min
    apc_store('sales_user_instances', $instances, 120);
  }
  return $instances;
}

/**
 * Get all the demo / evaluation deployments for Sales Team only
 *
 * @return array
 */
function getGlobalSalesDemoInstances()
{
  $instances = apc_fetch('sales_demo_instances');
  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $all_instances=getGlobalAcceptanceInstances();
    foreach ($all_instances as $plf_branch => $descriptor_arrays) {
      $filtered_instances=filterInstancesWithLabels($descriptor_arrays, array("sales","demo"), true);
      if (count($filtered_instances)>0) {
        $instances[$plf_branch]=$filtered_instances;
      }
    }
    if (count($instances)==0) {
      $instances[]=array();
    }
    // Instances will be cached for 2 min
    apc_store('sales_demo_instances', $instances, 120);
  }
  return $instances;
}

/**
 * Get all the deployments related to QA
 *
 * @return array
 */
function getGlobalQAInstances() {
  $instances = apc_fetch('qa_instances');
  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $all_instances=getGlobalAcceptanceInstances();
    foreach ($all_instances as $plf_branch => $descriptor_arrays) {
      $filtered_instances=filterInstancesWithLabels($descriptor_arrays, array("qa"));
      if (count($filtered_instances)>0) {
        $instances[$plf_branch]=$filtered_instances;
      }
    }
    if (count($instances)==0) {
      $instances=array();
    }
    // Instances will be cached for 2 min
    apc_store('qa_instances', $instances, 120);
  }
  return $instances;
}

/**
 * Get all the deployments related to Company
 *
 * @return array
 */
function getGlobalCompanyInstances() {
  $instances = apc_fetch('company_instances');
  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $all_instances=getGlobalAcceptanceInstances();
    foreach ($all_instances as $plf_branch => $descriptor_arrays) {
      $filtered_instances=filterInstancesWithLabels($descriptor_arrays, array("company"));
      if (count($filtered_instances)>0) {
        $instances[$plf_branch]=$filtered_instances;
      }
    }
    if (count($instances)==0) {
      $instances=array(array());
    }
    // Instances will be cached for 2 min
    apc_store('company_instances', $instances, 120);
  }
  return $instances;
}

/**
 * Get all the deployments related to documentation
 *
 * @return array
 */
function getGlobalDocInstances() {
  $instances = apc_fetch('doc_instances');
  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $all_instances=getGlobalAcceptanceInstances();
    foreach ($all_instances as $plf_branch => $descriptor_arrays) {
      $filtered_instances=filterInstancesWithLabels($descriptor_arrays, array("doc"));
      if (count($filtered_instances)>0) {
        $instances[$plf_branch]=$filtered_instances;
      }
    }
    if (count($instances)==0) {
      $instances=array();
    }
    // Instances will be cached for 2 min
    apc_store('doc_instances', $instances, 120);
  }
  return $instances;
}

/**
 * Get all the deployments related to translation
 *
 * @return array
 */
function getGlobalTranslationInstances() {
  $instances = apc_fetch('translation_instances');
  if (empty($instances) || getenv('ADT_DEV_MODE')) {
    $all_instances=getGlobalAcceptanceInstances();
    foreach ($all_instances as $plf_branch => $descriptor_arrays) {
      $filtered_instances=filterInstancesWithLabels($descriptor_arrays, array("translation"));
      if (count($filtered_instances)>0) {
        $instances[$plf_branch]=$filtered_instances;
      }
    }
    if (count($instances)==0) {
      $instances=array();
    }
    // Instances will be cached for 2 min
    apc_store('translation_instances', $instances, 120);
  }
  return $instances;
}

/**
 * Test if the instance is a feature branch deployment
 *
 * @param $descriptor_arrays
 *
 * @return bool
 */
function isInstanceFeatureBranch($descriptor_arrays) {
  if ( !empty($descriptor_arrays->BRANCH_NAME) && strpos($descriptor_arrays->BRANCH_NAME, "translation") === false ) {
    return true;
  } elseif (isInstanceWithLabels($descriptor_arrays, array('fb')) ) {
    return true;
  } else {
    return false;
  }
}

/**
 * Test if the instance is a translation deployment
 *
 * @param $descriptor_arrays
 *
 * @return bool
 */
function isInstanceTranslation($descriptor_arrays) {
  if ( !empty($descriptor_arrays->BRANCH_NAME) && strpos($descriptor_arrays->BRANCH_NAME, "translation") === true ) {
    return true;
  } elseif (isInstanceWithLabels($descriptor_arrays, array('translation')) ) {
    return true;
  } else {
    return false;
  }
}

/**
 * Test if the instance is a Documentation deployment
 *
 * @param $descriptor_arrays
 *
 * @return bool
 */
function isInstanceDoc($descriptor_arrays) {
  return isInstanceWithLabels($descriptor_arrays, array('doc'));
}

/**
 * Test if the instance is a QA deployment
 *
 * @param $descriptor_arrays
 *
 * @return bool
 */
function isInstanceQA($descriptor_arrays) {
  return isInstanceWithLabels($descriptor_arrays, array('qa'));
}

/**
 * Test if the instance is a Company deployment
 *
 * @param $descriptor_arrays
 *
 * @return bool
 */
function isInstanceCompany($descriptor_arrays) {
  return isInstanceWithLabels($descriptor_arrays, array('company'));
}

/**
 * Test if an instance has at least 1 or all labels.
 *
 * @param      $instance   the instance to test
 * @param      $labels     the labels to search
 * @param bool $all_labels do we check if the instance has all labels or at least one ?
 *
 * @return bool
 */
function isInstanceWithLabels($instance, $labels, $all_labels = false) {
  if (!property_exists($instance, 'DEPLOYMENT_LABELS')) {
    return false;
  }
  if (is_array($instance->DEPLOYMENT_LABELS)) {
    $instance_labels = $instance->DEPLOYMENT_LABELS;
  } else {
    $instance_labels[] = $instance->DEPLOYMENT_LABELS;
  }
  if (count($instance_labels) == 0) {
    return false;
  }
  if (is_array($labels)) {
    $result = false;
    foreach ($labels as $label) {
      $label_present = in_array($label, $instance_labels);
      if ($all_labels && $label_present == false) {
        return false;
      } elseif ($all_labels && $label_present) {
        $result = $label_present;
      } elseif ($all_labels == false && $label_present) {
        return true;
      } elseif ($all_labels == false && $label_present == false) {
        $result = $label_present;
      }
    }
    return $result;
  } else {
    return in_array($labels, $instance_labels);
  }
}

/**
 * Filter a deployment descriptor array and keep all the deployments matching a particular set of labels
 *
 * @param      $descriptor_arrays     an array of deployment descriptors
 * @param      $labels                one or more labels
 * @param bool $all_labels            filtered deployment must match all labels or not
 *
 * @return array
 */
function filterInstancesWithLabels($descriptor_arrays, $labels, $all_labels = false) {
  $instances = array();
  foreach ($descriptor_arrays as $descriptor_array) {
    if (isInstanceWithLabels($descriptor_array, $labels, $all_labels)) {
      $instances[] = $descriptor_array;
    }
  }
  return $instances;
}

/**
 * Filter a deployment descriptor array and remove all the deployments matching a particular set of labels
 *
 * @param      $descriptor_arrays     an array of deployment descriptors
 * @param      $labels                one or more labels
 * @param bool $all_labels            filtered deployment must match all labels or not
 *
 * @return array
 */
function filterInstancesWithoutLabels($descriptor_arrays, $labels, $all_labels = false) {
  $instances = array();
  foreach ($descriptor_arrays as $descriptor_array) {
    if (!isInstanceWithLabels($descriptor_array, $labels, $all_labels)) {
      $instances[] = $descriptor_array;
    }
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

/*
* Check if the user is authorized to read and download the file.
* Only Apache, Tomcat and JBoss logs can be viewed and downloaded.
*/
function isAuthorizedToReadFile($log_type, $file_path)
{
  if (!empty($log_type) && !is_null($log_type)){
      if ($log_type == "instance" && (strpos($file_path, 'catalina.out') !== false
            || strpos($file_path, 'server.log') !== false)){
        return true;
      }
      if ($log_type == "apache" && strpos($file_path, 'access.log') !== false){
        return true;
      }
      return false;
  }
  return false;
}

/*
* Check if a log file can be viewed in HTML page
*/
function isFileTooLargeToBeViewed($file_path)
{
  $limit = 3145728; // 3Mo (in bytes)
  if (file_exists($file_path) && filesize($file_path) < $limit) {
    return false;
  }
  return true;
}

/*
* Display file size more readable for human.
*/
function human_filesize($bytes, $decimals = 2)
{
  $sz = 'BKMGTP';
  $factor = floor((strlen($bytes) - 1) / 3);
  return sprintf("%.{$decimals}f", $bytes / pow(1024, $factor)) . @$sz[$factor];
}

?>
