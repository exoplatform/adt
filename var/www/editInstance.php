<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_POST['key'])) {
    $file_path = getenv('ADT_DATA') . "/conf/instances/" . basename($_POST['key']) . ".note";
    
    if (!empty($_POST['note'])) {
        file_put_contents($file_path, $_POST['note']);
    } elseif (file_exists($file_path)) {
        unlink($file_path);
    }
    
    // Clear caches and redirect
    clearCaches();
    header("Location: " . filter_var($_POST['from'], FILTER_SANITIZE_URL));
    exit;
}

// If not a POST request or missing key, redirect to home
header("Location: /");
exit;