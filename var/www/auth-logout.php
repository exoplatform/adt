<?php
require_once(dirname(__FILE__) . '/lib/functions-auth.php');
logout_user();
$redirect = '/auth-login.php';
if (!empty($_GET['redirect'])) {
    $redirect = $_GET['redirect'];
}
header('Location: ' . $redirect);
exit;
