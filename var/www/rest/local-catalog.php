<?php 
if(!isset($_GET["plfversion"])){
    http_response_code(404);
    echo "Error! Missing PLF version parameter!";
    die();
}
// Continous deployment version check
if(!preg_match('/^[0-9].[0-9].[0-9]-[0-9]{8}$/', $_GET["plfversion"])){
    http_response_code(404);
    echo "Error! Invalid PLF version parameter value!";
    die();
}
if (!file_exists("../catalog/local_catalog.json")) {
    http_response_code(500);
    echo "Error! Could not find local catalog file!";
    die();
}
$local_catalog = file_get_contents("../catalog/local_catalog.json");
if ($local_catalog === false) {
    http_response_code(500);
    echo "Error! Could not parse local catalog file!";
    die();
}
$plf_version=$_GET["plfversion"];
$plf_suffix= preg_replace("/^[0-9].[0-9].[0-9]/", '', $plf_version);
$local_catalog = str_replace("@exo_plf_version_suffix",$plf_suffix,$local_catalog);
$local_catalog = str_replace("@exo_plf_version",$plf_version,$local_catalog);
if(isset($_GET["remote"])){
    $remote_catalog = file_get_contents('http://'.$_GET["remote"]);
} else {
    $remote_catalog = file_get_contents("https://www.exoplatform.com/addons/catalog");
}
header("Content-type: application/json; charset=utf-8");
// Merge remote catalog and local catalog and print result
echo str_replace("\/","/",json_encode(array_merge(json_decode($local_catalog, true),json_decode($remote_catalog, true)),JSON_PRETTY_PRINT));
?>