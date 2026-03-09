<?php
require_once(dirname(__FILE__) . '/lib/functions.php');

if( !empty($_POST['note']) ) {
    file_put_contents(getenv('ADT_DATA') . "/conf/instances/" . $_POST['key'] . ".note", $_POST['note']);
} else {
    // Remove any existing value by removing the file
    if ( file_exists(getenv('ADT_DATA') . "/conf/instances/" . $_POST['key'] . ".note") ) {
        unlink(getenv('ADT_DATA') . "/conf/instances/" . $_POST['key'] . ".note");
    }
}

// Flush caches to ensure changes are reflected immediately
clearCaches();

// Get the referring page URL
$redirect_url = $_POST['from'];

// Add cache clearing parameter if not already present
if (strpos($redirect_url, '?') === false) {
    $redirect_url .= '?clearCaches=true';
} else {
    $redirect_url .= '&clearCaches=true';
}

header("Location: " . $redirect_url);
exit;
?>