<?php 

function searchDuplicateCatalog($arr, $obj) {
    foreach ($arr as $value) {
        if ($value['id'] == $obj['id'] && $value['version'] == $obj['version']) {
            return true;
        }
    }
    return false;
};

if(!isset($_GET["plfversion"])){
    http_response_code(404);
    echo "Error! Missing PLF version parameter!";
    die();
}
$stagingCatalog = isset($_GET["staging"]) && $_GET["staging"] === 'true'; 
$targetCatalog = $stagingCatalog ? 'staging' : 'local';
// Continous deployment version check
if(!preg_match('/^[0-9].[0-9].[0-9](-(exo|meed))?-[0-9]{8,10}$/', $_GET["plfversion"])){
    http_response_code(404);
    echo "Error! Invalid PLF version parameter value!";
    die();
}
$exo_plf_major_version="";
if ( preg_match('/^[0-9].[0-9]/', $_GET["plfversion"], $matches) ) {
    $exo_plf_major_version=$matches[1];
}
if (!file_exists("../catalog/".$exo_plf_major_version."/".$targetCatalog."_catalog.json")) {
    http_response_code(404);
    echo "Error! Could not find ".$targetCatalog." catalog file for ".$exo_plf_major_version." version!";
    die();
}
$local_catalog = file_get_contents("../catalog/".$exo_plf_major_version."/".$targetCatalog."_catalog.json");
if ($local_catalog === false) {
    http_response_code(500);
    echo "Error! Could not parse ".$targetCatalog." catalog file!";
    die();
}
$plf_version=$_GET["plfversion"];
$plf_suffix= preg_replace("/^[0-9].[0-9].[0-9](-(exo|meed))?/", '', $plf_version);
$local_catalog = str_replace("@exo_plf_version_suffix",$plf_suffix,$local_catalog);
$local_catalog = str_replace("@exo_plf_version",$plf_version,$local_catalog);
if(isset($_GET["remote"])){
    $remote_catalog = file_get_contents('http://addons.exoplatform.org/'.$_GET["remote"]);
} else {
    $remote_catalog = file_get_contents("https://www.exoplatform.com/addons/catalog");
}
header("Content-type: application/json; charset=utf-8");
// Merge remote catalog and local catalog and print result; Merge order is crucial for staging catalog duplicates removal.
$mergedArray=array_merge(json_decode($local_catalog, true),json_decode($remote_catalog, true));
if ($stagingCatalog) {
    $uniqueArray = array();
    foreach ($mergedArray as $obj) {
        if (searchDuplicateCatalog($uniqueArray, $obj) === false) {
            $uniqueArray[] = $obj;
        }
    }
    echo str_replace("\/","/",json_encode($uniqueArray,JSON_PRETTY_PRINT));
} else {
    echo str_replace("\/","/",json_encode($mergedArray,JSON_PRETTY_PRINT));
}
?>