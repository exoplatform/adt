<?php 

if(isset($_GET["remote"])){
    $remote_catalog = file_get_contents('http://addons.exoplatform.org/'.$_GET["remote"]);
} else {
    $remote_catalog = file_get_contents("https://www.exoplatform.com/addons/catalog");
}
$extra_catalog = '';
if(isset($_GET["extra"])){
    $extra_catalog = file_get_contents('http://addons.exoplatform.org/'.$_GET["extra"]);
} else {
    http_response_code(404);
    echo "Error! Missing extra catalog parameter!";
    die();
}
header("Content-type: application/json; charset=utf-8");
// Merge remote catalog and extra catalog and print result
echo str_replace("\/","/",json_encode(array_merge(json_decode($remote_catalog, true),json_decode($extra_catalog, true)),JSON_PRETTY_PRINT));
?>