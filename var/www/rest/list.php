<?php
require_once(dirname(__FILE__) . '/../lib/functions.php');
checkCaches();
// Display the list in JSON
echo json_encode(getLocalAcceptanceInstances());
?>