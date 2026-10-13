<?php
require_once(__DIR__ . '/lib/functions.php');

$note_file = getenv('ADT_DATA') . "/conf/instances/" . basename($_POST['key'] ?? '') . ".note";

auditLog('instance.edit', ['key' => basename($_POST['key'] ?? ''), 'note' => !empty($_POST['note']) ? 'set' : 'removed']);
if( !empty($_POST['note']) ) {
    file_put_contents($note_file, $_POST['note']);
} else {
    // Remove any existing value by removing the file
    if ( file_exists($note_file) ) {
        unlink($note_file);
    }
}

// Flush caches to ensure changes are reflected immediately
clearCaches();

// Get the referring page URL
$redirect_url = sanitizeLocalRedirect($_POST['from'] ?? null);

// Add cache clearing parameter if not already present
if (!str_contains($redirect_url, '?')) {
    $redirect_url .= '?clearCaches=true';
} else {
    $redirect_url .= '&clearCaches=true';
}

header("Location: " . $redirect_url);
exit;
?>