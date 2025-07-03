<?php
declare(strict_types=1);

// Set timezone
date_default_timezone_set("UTC");

// Allow to invalidate caches
require_once __DIR__ . '/lib/functions.php';
checkCaches();

// Configuration
$config = [
    "hostsAllowed" => [],  // Optional array of authorized client IPs
    "directoryIndex" => "index.php",
    "allowedExtensions" => ["php", "jpg", "jpeg", "gif", "css", "png", "ico", "svg"]
];

// Logging function
function logAccess(int $status = 200): void {
    file_put_contents("php://stdout", sprintf(
        "[%s] %s:%s [%s]: %s\n",
        date("D M j H:i:s Y"),
        $_SERVER["REMOTE_ADDR"],
        $_SERVER["REMOTE_PORT"],
        $status,
        $_SERVER["REQUEST_URI"]
    ));
}

// Check allowed hosts
if (!empty($config['hostsAllowed']) && !in_array($_SERVER['REMOTE_ADDR'], $config['hostsAllowed'])) {
    logAccess(403);
    http_response_code(403);
    header("Location: /403.html");
    exit;
}

// Parse URL
$path = parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH);
$ext = pathinfo($path, PATHINFO_EXTENSION);

// Handle directory requests
if (empty($ext)) {
    $path = rtrim($path, "/") . "/" . $config["directoryIndex"];
}

// Serve static assets or existing files
if (in_array($ext, $config["allowedExtensions"])) {
    return false;
}

// Handle ZIP downloads
if ($ext === "zip" && file_exists(getenv('ADT_DATA') . $path)) {
    header("Content-Type: application/octet-stream");
    readfile(getenv('ADT_DATA') . $path);
    exit;
}

// Serve existing files
if (file_exists($_SERVER["DOCUMENT_ROOT"] . $path)) {
    return false;
}

// Default 404 behavior
logAccess(404);
http_response_code(404);
header("Location: /404.html");
exit;