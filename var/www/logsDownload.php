<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';

$file = $_GET['file'] ?? '';
$type = $_GET['type'] ?? '';

if (!isAuthorizedToReadFile($type, $file)) {
    header("HTTP/1.1 403 Forbidden");
    exit("<span style=\"color:red\"><strong>Not authorized to download this file.</strong></span>");
}

if (file_exists($file)) {
    header('Content-Description: File Transfer');
    header('Content-Type: application/octet-stream');
    header('Content-Disposition: attachment; filename="' . basename($file) . '"');
    header('Expires: 0');
    header('Cache-Control: must-revalidate');
    header('Pragma: public');
    header('Content-Length: ' . filesize($file));
    readfile($file);
    exit;
}

header("HTTP/1.1 404 Not Found");
exit("<span style=\"color:red\"><strong>File not found.</strong></span>");