<?php
/**
 * REST API: list all local instances as JSON.
 */
header('Content-Type: application/json');
require_once __DIR__ . '/../lib/functions.php';
echo json_encode(getAllInstancesForApi(), JSON_PRETTY_PRINT);
