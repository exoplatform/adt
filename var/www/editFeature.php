<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
if( !empty($_POST['product']) && !empty($_POST['version']) && !empty($_POST['server'])  ){
    file_put_contents(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".spec", $_POST['specifications']);
    file_put_contents(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".status", $_POST['status']);
    file_put_contents(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".issue", $_POST['issue']);
    if ($_POST['branch'] !== "UNSET") {
        file_put_contents(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".branch", $_POST['branch']);
    } else {
        // Remove any existing value by removing the file
        unlink(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".branch");
    }
}
// Flush caches
clearCaches();
header("Location: " . $_POST['from'] . "?clearCaches=true"); /* Redirect browser */
/* Make sure that code below does not get executed when we redirect. */
exit;
?>