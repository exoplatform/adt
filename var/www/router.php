<?php
// PHP built-in server router (dev mode).
// Serves static files when they exist, else falls back to index.php.
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$file = __DIR__ . $uri;
if ($uri !== '/' && file_exists($file) && !is_dir($file)) {
    return false; // let php serve the static file
}
require __DIR__ . '/index.php';
