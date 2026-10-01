<?php
// Live usage of all acceptance servers, polled by the servers page (behind the
// usual LDAP auth, unlike /rest/ which is restricted to exoplatform.org hosts)
require_once(dirname(__FILE__) . '/lib/functions.php');
header("Content-type: application/json; charset=utf-8");
header("Cache-Control: no-store");
echo json_encode(getGlobalServerStats());
?>
