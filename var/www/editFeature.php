<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_POST['key'])) {
    $file_base = getenv('ADT_DATA') . "/conf/features/" . basename($_POST['key']);
    
    // Handle file operations
    $files = [
        'spec' => $file_base . ".spec",
        'status' => $file_base . ".status",
        'issue' => $file_base . ".issue",
        'description' => $file_base . ".desc",
        'branch' => $file_base . ".branch"
    ];
    
    foreach ($files as $field => $file_path) {
        if (isset($_POST[$field]) && $_POST[$field] !== '') {
            if ($field === 'branch' && $_POST[$field] === 'UNSET') {
                if (file_exists($file_path)) {
                    unlink($file_path);
                }
            } else {
                file_put_contents($file_path, $_POST[$field]);
            }
        } elseif (file_exists($file_path)) {
            unlink($file_path);
        }
    }
    
    // Clear caches and redirect
    clearCaches();
    header("Location: " . filter_var($_POST['from'], FILTER_SANITIZE_URL));
    exit;
}

// If not a POST request or missing key, redirect to home
header("Location: /");
exit;