<?php
file_put_contents(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".spec", $_POST['specifications']);
file_put_contents(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".status", $_POST['status']);
file_put_contents(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".issue", $_POST['issue']);
file_put_contents(getenv('ADT_DATA') . "/conf/features/" . $_POST['product'] . "-" . $_POST['version'] . "." . $_POST['server'] . ".branch", $_POST['branch']);
// Flush caches
apc_delete("all_instances");
apc_delete("local_instances");
header("Location: " . $_POST['from']); /* Redirect browser */
/* Make sure that code below does not get executed when we redirect. */
exit;
?>