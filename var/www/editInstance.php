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

// Flush caches
clearCaches();
header("Location: " . $_POST['from'] . "?clearCaches=true"); /* Redirect browser */
/* Make sure that code below does not get executed when we redirect. */
exit;
?>
