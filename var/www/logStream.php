<?php
require_once(dirname(__FILE__) . '/lib/functions.php');

$file_path = $_GET['file'];
$log_type = $_GET['type'];
$offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;

header('Content-Type: application/json');

if (!isAuthorizedToReadFile($log_type, $file_path)) {
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

if (!file_exists($file_path)) {
    echo json_encode(['error' => 'File not found']);
    exit;
}

$filesize = filesize($file_path);

if ($offset > $filesize) {
    $offset = 0; // reset if file rotated
}

$handle = fopen($file_path, 'rb');
fseek($handle, $offset);
$content = fread($handle, $filesize - $offset);
fclose($handle);

echo json_encode([
    'offset' => $filesize,
    'content' => htmlspecialchars($content, ENT_NOQUOTES, 'UTF-8')
]);
