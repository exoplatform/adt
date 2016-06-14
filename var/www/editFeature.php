<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
if( !empty($_POST['key']) ){
    $file_base = getenv('ADT_DATA') . "/conf/features/" . $_POST['key'];
    $file_spec = $file_base  . ".spec";
    $file_status = $file_base . ".status";
    $file_issue = $file_base . ".issue";
    $file_desc = $file_base . ".desc";
    $file_branch = $file_base . ".branch";

    if( !empty($_POST['specifications']) ) {
        file_put_contents($file_spec, $_POST['specifications']);
    } else {
        // Remove any existing value by removing the file
        if ( file_exists($file_spec) ) {
            unlink($file);
        }
    }
    if( !empty($_POST['status']) ) {
        file_put_contents($file_status, $_POST['status']);
    } else {
        // Remove any existing value by removing the file
        if ( file_exists($file_status) ) {
            unlink($file_status);
        }
    }
    if( !empty($_POST['issue']) ) {
        file_put_contents($file_issue, $_POST['issue']);
    } else {
        // Remove any existing value by removing the file
        if ( file_exists($file_issue) ) {
            unlink($file_issue);
        }
    }
    if( !empty($_POST['description']) ) {
        file_put_contents($file_description, $_POST['description']);
    } else {
        // Remove any existing value by removing the file
        if ( file_exists($file_description) ) {
            unlink($file_description);
        }
    }
    if ($_POST['branch'] !== "UNSET") {
        file_put_contents($file_branch, $_POST['branch']);
    } else {
        // Remove any existing value by removing the file
        if ( file_exists($file_branch) ) {
          unlink($file_branch);
        }
    }
}
// Flush caches
clearCaches();
header("Location: " . $_POST['from'] . "?clearCaches=true"); /* Redirect browser */
/* Make sure that code below does not get executed when we redirect. */
exit;
?>