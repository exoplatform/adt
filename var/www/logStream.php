<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');

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

if ($filesize > $offset) {
    $handle = fopen($file_path, "rb");
    fseek($handle, $offset);
    $content = fread($handle, $filesize - $offset);
    fclose($handle);

    echo json_encode([
        'offset' => $filesize,
        'content' => ansi_to_html($content)
    ]);
} else {
    // Nothing new to read — just return current offset and empty content
    echo json_encode([
        'offset' => $filesize,
        'content' => ''
    ]);
}