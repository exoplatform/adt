<?php
require_once(__DIR__ . '/../lib/functions.php');
header("Content-type: application/json; charset=utf-8");
header("Cache-Control: no-store");
echo json_encode(getLocalServerStats());
?>
