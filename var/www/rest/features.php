<?php
require_once(dirname(__FILE__) . '/../lib/functions.php');
checkCaches();

$projectsNames = getRepositories();
$projects = array_keys(getRepositories());
$features = getFeatureBranches($projects);
$translations = getTranslationBranches($projects);
$meedsProjectsNames = getMeedsRepositories();
$meedsProjects = array_keys($meedsProjectsNames);
$baseBranches = getBaseBranches($meedsProjects);

$acceptanceBranches = getAcceptanceBranches();

// Filter accepted features
$acceptedFeatures = array_filter($features, function($feature, $name) use ($acceptanceBranches) {
    return in_array($name, $acceptanceBranches) && !isTranslation($name);
}, ARRAY_FILTER_USE_BOTH);

// Filter other features (not accepted, not backup)
$otherFeatures = array_filter($features, function($feature, $name) use ($acceptanceBranches) {
    return !in_array($name, $acceptanceBranches) && !isBackup($name);
}, ARRAY_FILTER_USE_BOTH);

$data = [
    'acceptedFeatures' => $acceptedFeatures,
    'otherFeatures' => $otherFeatures,
    'translations' => $translations,
    'baseBranches' => $baseBranches,
    'projects' => $projectsNames,
    'meedsProjects' => $meedsProjectsNames
];

header('Content-Type: application/json');
echo json_encode($data);
?>
