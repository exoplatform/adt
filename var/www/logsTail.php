<?php
require_once(dirname(__FILE__) . '/lib/functions.php');

header('Content-Type: application/json');
header('Cache-Control: no-store');

$file_path = $_GET['file'] ?? '';
$log_type = $_GET['type'] ?? '';
$offset = isset($_GET['offset']) ? max(0, (int) $_GET['offset']) : 0;

if (!isAuthorizedToReadFile($log_type, $file_path) || !file_exists($file_path)) {
    http_response_code(403);
    echo json_encode(['error' => 'Not authorized to read this file.']);
    exit;
}

$tail = readFileTail($file_path, $offset);

echo json_encode([
    'size' => $tail['size'],
    'truncated' => $tail['truncated'],
    'skipped' => $tail['skipped'],
    'data' => ansiToHtml(htmlspecialchars($tail['data'], ENT_NOQUOTES, 'UTF-8')),
]);
