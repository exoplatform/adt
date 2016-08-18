<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
$file = $_GET['file'];
$type = $_GET['type'];

if (file_exists($file) && isAuthorizedToReadFile($type, $file)) {
    header('Content-Description: File Transfer');
    header('Content-Type: application/octet-stream');
    header('Content-Disposition: attachment; filename="'.basename($file).'"');
    header('Expires: 0');
    header('Cache-Control: must-revalidate');
    header('Pragma: public');
    header('Content-Length: ' . filesize($file));
    readfile($file);
    exit;
} else {
    printf("<span style=\"color:red\"><strong>Not authorized to download this file.</strong></span>");
}
?>
