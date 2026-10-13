<?php
require_once(__DIR__ . '/../lib/functions.php');
checkCaches();
// Display the list in JSON
echo json_encode(getLocalAcceptanceInstances());
?>