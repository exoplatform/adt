<?php
if (session_status() === PHP_SESSION_NONE) {
    session_name('ADT_SESSION');
    session_set_cookie_params([
        'lifetime' => 0,
        'path' => '/',
        'domain' => '',
        'secure' => !empty($_SERVER['HTTPS']),
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
    session_start();
}

define('AUTH_TOKEN_DIR', (getenv('ADT_DATA') ?: '/tmp/adt') . '/var/auth/tokens');
define('AUTH_TOKEN_EXPIRY', 2592000);
define('AUTH_SESSION_EXPIRY', 28800);

if (!function_exists('ldap_escape')) {
    function ldap_escape($subject, $ignore = '', $flags = 0) {
        $hex = '';
        if ($flags & LDAP_ESCAPE_FILTER) {
            $hex = array('\\', '*', '(', ')', "\x00");
        }
        if ($flags & LDAP_ESCAPE_DN) {
            $hex = array_merge($hex ?: array(), array('\\', ',', '=', '+', '<', '>', ';', '"', '#'));
        }
        if (!$flags) {
            $hex = array('\\', '*', '(', ')', "\x00", ',', '=', '+', '<', '>', ';', '"', '#');
        }
        $hex = array_unique($hex);
        $ignore_chars = str_split($ignore);
        $result = '';
        for ($i = 0; $i < strlen($subject); $i++) {
            $char = $subject[$i];
            if (in_array($char, $ignore_chars)) {
                $result .= $char;
            } elseif (in_array($char, $hex)) {
                $result .= '\\' . strtoupper(dechex(ord($char)));
            } else {
                $result .= $char;
            }
        }
        return $result;
    }
}

if (!function_exists('random_bytes')) {
    function random_bytes($length) {
        $raw = '';
        if (function_exists('openssl_random_pseudo_bytes')
            && ($raw = @openssl_random_pseudo_bytes($length)) !== false
            && strlen($raw) === $length
        ) {
            return $raw;
        }
        if (is_readable('/dev/urandom') && ($fh = @fopen('/dev/urandom', 'rb'))) {
            $raw = @fread($fh, $length);
            @fclose($fh);
            if (strlen($raw) === $length) {
                return $raw;
            }
        }
        $raw = '';
        for ($i = 0; $i < $length; $i++) {
            $raw .= chr(mt_rand(0, 255));
        }
        return $raw;
    }
}

function getLdapConfig() {
    return array(
        'host'       => getenv('LDAP_ACCEPTANCE_HOST') ?: 'ldap2.exoplatform.org',
        'port'       => getenv('LDAP_ACCEPTANCE_PORT') ?: 636,
        'use_ssl'    => true,
        'bind_dn'    => getenv('LDAP_ACCEPTANCE_BIND_DN'),
        'bind_pass'  => getenv('LDAP_ACCEPTANCE_BIND_PASSWORD'),
        'base_dn'    => getenv('LDAP_ACCEPTANCE_BASE_DN') ?: 'ou=users,ou=portal,dc=exoplatform,dc=org',
        'group_dn'   => getenv('LDAP_ACCEPTANCE_GROUP_DN') ?: 'cn=exo-employees,ou=groups,dc=exoplatform,dc=org',
        'user_attr'  => getenv('LDAP_ACCEPTANCE_USER_ATTR') ?: 'cn',
    );
}

function authenticate_user($username, $password) {
    $config = getLdapConfig();
    if (empty($config['bind_dn']) || empty($config['bind_pass'])) {
        return false;
    }
    if (!function_exists('ldap_connect')) {
        return false;
    }
    $host = ($config['use_ssl'] ? 'ldaps://' : 'ldap://') . $config['host'];

    $ldapconn = @ldap_connect($host, $config['port']);
    if (!$ldapconn) {
        return false;
    }
    ldap_set_option($ldapconn, LDAP_OPT_PROTOCOL_VERSION, 3);
    ldap_set_option($ldapconn, LDAP_OPT_REFERRALS, 0);
    ldap_set_option($ldapconn, LDAP_OPT_NETWORK_TIMEOUT, 5);

    $tls_require_cert = getenv('LDAP_ACCEPTANCE_TLS_REQUIRE_CERT');
    if ($tls_require_cert !== false && $tls_require_cert !== '') {
        $tls_map = array('never' => 0, 'hard' => 1, 'demand' => 2, 'allow' => 3, 'try' => 3);
        $tls_val = isset($tls_map[strtolower($tls_require_cert)]) ? $tls_map[strtolower($tls_require_cert)] : (int)$tls_require_cert;
        ldap_set_option($ldapconn, LDAP_OPT_X_TLS_REQUIRE_CERT, $tls_val);
    }

    if (!@ldap_bind($ldapconn, $config['bind_dn'], $config['bind_pass'])) {
        ldap_close($ldapconn);
        return false;
    }

    $escaped_username = ldap_escape($username, '', LDAP_ESCAPE_FILTER);
    $filter = '(' . $config['user_attr'] . '=' . $escaped_username . ')';
    $search = @ldap_search($ldapconn, $config['base_dn'], $filter, array('dn', $config['user_attr'], 'mail', 'cn'));
    if (!$search) {
        ldap_close($ldapconn);
        return false;
    }
    $entries = ldap_get_entries($ldapconn, $search);
    if ($entries['count'] == 0) {
        ldap_close($ldapconn);
        return false;
    }
    $user_dn = $entries[0]['dn'];

    if (!@ldap_bind($ldapconn, $user_dn, $password)) {
        ldap_close($ldapconn);
        return false;
    }

    $member_check = @ldap_compare($ldapconn, $config['group_dn'], 'member', $user_dn);
    if ($member_check !== true) {
        $member_check = @ldap_compare($ldapconn, $config['group_dn'], 'uniqueMember', $user_dn);
    }
    if ($member_check !== true) {
        ldap_close($ldapconn);
        return false;
    }

    $user_info = array(
        'username' => $username,
        'dn'       => $user_dn,
        'cn'       => $entries[0][strtolower($config['user_attr'])][0] ?? $username,
        'mail'     => $entries[0]['mail'][0] ?? '',
    );
    ldap_close($ldapconn);
    return $user_info;
}

function cleanup_expired_tokens() {
    $token_dir = AUTH_TOKEN_DIR;
    if (!is_dir($token_dir)) {
        return;
    }
    $now = time();
    $dh = opendir($token_dir);
    while (($file = readdir($dh)) !== false) {
        if ($file === '.' || $file === '..' || strlen($file) !== 64) {
            continue;
        }
        $path = $token_dir . '/' . $file;
        $data = @file_get_contents($path);
        if ($data === false) {
            continue;
        }
        $expires = (int)explode("\n", $data, 2)[0];
        if ($expires < $now) {
            @unlink($path);
        }
    }
    closedir($dh);
}

function is_authenticated() {
    if (isset($_SESSION['auth_user']) && isset($_SESSION['auth_expires'])) {
        if (time() < $_SESSION['auth_expires']) {
            $_SESSION['auth_expires'] = time() + AUTH_SESSION_EXPIRY;
            return $_SESSION['auth_user'];
        }
    }

    return validate_remember_token();
}

function validate_remember_token() {
    if (empty($_COOKIE['adt_remember'])) {
        return false;
    }
    $token = $_COOKIE['adt_remember'];
    if (!preg_match('/^[a-f0-9]{64}$/', $token)) {
        return false;
    }
    $token_file = AUTH_TOKEN_DIR . '/' . $token;
    if (!file_exists($token_file)) {
        return false;
    }
    $data = @file_get_contents($token_file);
    if ($data === false) {
        return false;
    }
    $parts = explode("\n", $data, 3);
    if (count($parts) < 2) {
        @unlink($token_file);
        return false;
    }
    $expires = (int)$parts[0];
    $username = trim($parts[1]);
    if (time() > $expires) {
        @unlink($token_file);
        return false;
    }

    $_SESSION['auth_user'] = $username;
    $_SESSION['auth_expires'] = time() + AUTH_SESSION_EXPIRY;
    return $username;
}

function create_remember_token($username) {
    $token_dir = AUTH_TOKEN_DIR;
    if (!is_dir($token_dir)) {
        @mkdir($token_dir, 0700, true);
    }
    $token = bin2hex(random_bytes(32));
    $expires = time() + AUTH_TOKEN_EXPIRY;
    file_put_contents($token_dir . '/' . $token, $expires . "\n" . $username, LOCK_EX);
    setcookie('adt_remember', $token, $expires, '/', '', !empty($_SERVER['HTTPS']), true);
}

function clear_remember_token() {
    if (!empty($_COOKIE['adt_remember'])) {
        $token = $_COOKIE['adt_remember'];
        $token_file = AUTH_TOKEN_DIR . '/' . $token;
        if (file_exists($token_file)) {
            @unlink($token_file);
        }
        setcookie('adt_remember', '', time() - 3600, '/', '', !empty($_SERVER['HTTPS']), true);
    }
}

function login_user($username, $password, $remember = false) {
    $user = authenticate_user($username, $password);
    if ($user === false) {
        return false;
    }
    session_regenerate_id(true);
    $_SESSION['auth_user'] = $user['username'];
    $_SESSION['auth_expires'] = time() + AUTH_SESSION_EXPIRY;

    if ($remember) {
        create_remember_token($user['username']);
    }
    return $user;
}

function logout_user() {
    clear_remember_token();
    $_SESSION = array();
    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000,
            $params['path'], $params['domain'],
            $params['secure'], $params['httponly']
        );
    }
    session_destroy();
}

function get_redirect_url() {
    $url = '/';
    if (!empty($_GET['redirect'])) {
        $redirect = $_GET['redirect'];
        $parsed = parse_url($redirect);
        if (!empty($parsed['host']) && $parsed['host'] !== ($_SERVER['HTTP_HOST'] ?? '')) {
            return '/';
        }
        if (strpos($redirect, '/') === 0 && strpos($redirect, '//') !== 0) {
            $url = $redirect;
        }
    }
    return $url;
}

function auth_check() {
    $public_pages = array('/auth-login.php', '/auth-logout.php', '/style.css', '/403.html', '/404.html', '/500.html', '/502.html', '/503.html', '/robots.txt');

    $script = $_SERVER['SCRIPT_NAME'] ?? '';
    foreach ($public_pages as $page) {
        if (strpos($script, $page) !== false) {
            return;
        }
    }

    if (strpos($script, '/rest/') !== false) {
        return;
    }

    if (mt_rand(1, 100) === 1) {
        cleanup_expired_tokens();
    }

    $user = is_authenticated();
    if ($user === false) {
        $redirect = urlencode($_SERVER['REQUEST_URI']);
        header('Location: /auth-login.php?redirect=' . $redirect);
        exit;
    }
}
