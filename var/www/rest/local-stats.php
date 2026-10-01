<?php
require_once(dirname(__FILE__) . '/../lib/functions.php');
header("Content-type: application/json; charset=utf-8");
header("Cache-Control: no-store");
echo json_encode(getLocalServerStats());
?>
