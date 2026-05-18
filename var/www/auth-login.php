<?php
require_once(dirname(__FILE__) . '/lib/functions-auth.php');

$error = '';
$username = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    $remember = !empty($_POST['remember']);

    if (empty($username) || empty($password)) {
        $error = 'Please enter your username and password.';
    } else {
        $user = login_user($username, $password, $remember);
        if ($user === false) {
            $error = 'Invalid credentials or not authorized.';
            sleep(1);
        } else {
            $redirect = get_redirect_url();
            header('Location: ' . $redirect);
            exit;
        }
    }
}

$redirect = htmlspecialchars(get_redirect_url(), ENT_QUOTES, 'UTF-8');
$username = htmlspecialchars($username, ENT_QUOTES, 'UTF-8');
?><!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sign In - Acceptance</title>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
  <link href="./style.css" media="screen" rel="stylesheet" type="text/css" />
  <style>
    body {
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      background: linear-gradient(135deg, var(--navbar-start) 0%, var(--navbar-end) 100%);
      margin: 0;
      padding: 20px;
    }
    .login-card {
      width: 100%;
      max-width: 420px;
      background: var(--card-bg);
      border-radius: 16px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
      padding: 2.5rem 2rem;
    }
    .login-card .brand {
      text-align: center;
      margin-bottom: 2rem;
    }
    .login-card .brand i {
      font-size: 3rem;
      color: var(--secondary-color);
    }
    .login-card .brand h1 {
      font-size: 1.5rem;
      margin-top: 0.75rem;
      font-weight: 700;
      color: var(--bs-body-color);
    }
    .login-card .brand p {
      color: var(--text-muted);
      font-size: 0.9rem;
    }
    .login-card .form-control {
      border-radius: 10px;
      padding: 0.75rem 1rem;
      border: 2px solid var(--border-color);
      background: var(--body-bg);
      color: var(--bs-body-color);
      font-size: 1rem;
    }
    .login-card .form-control:focus {
      border-color: var(--secondary-color);
      box-shadow: 0 0 0 3px rgba(52,152,219,0.2);
    }
    .login-card .input-group-text {
      border-radius: 10px 0 0 10px;
      border: 2px solid var(--border-color);
      border-right: none;
      background: var(--body-bg);
      color: var(--text-muted);
    }
    .login-card .input-group .form-control {
      border-radius: 0 10px 10px 0;
    }
    .login-card .btn-primary {
      border-radius: 10px;
      padding: 0.75rem;
      font-weight: 600;
      font-size: 1rem;
      background: linear-gradient(135deg, var(--navbar-start) 0%, var(--navbar-end) 100%);
      border: none;
      transition: all 0.3s ease;
    }
    .login-card .btn-primary:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 25px rgba(102,126,234,0.4);
    }
    .login-card .form-check-input:checked {
      background-color: var(--secondary-color);
      border-color: var(--secondary-color);
    }
    .alert {
      border-radius: 10px;
      font-size: 0.9rem;
    }
    .login-footer {
      text-align: center;
      margin-top: 1.5rem;
      color: var(--text-muted);
      font-size: 0.8rem;
    }
  </style>
</head>
<body>
  <div class="login-card">
    <div class="brand">
      <i class="fas fa-cloud"></i>
      <h1>Welcome</h1>
      <p>Sign in to the Acceptance Dashboard</p>
    </div>

    <?php if ($error): ?>
      <div class="alert alert-danger d-flex align-items-center" role="alert">
        <i class="fas fa-exclamation-circle me-2"></i>
        <div><?= htmlspecialchars($error, ENT_QUOTES, 'UTF-8') ?></div>
      </div>
    <?php endif; ?>

    <form method="post" action="/auth-login.php">
      <?php if ($redirect !== '/'): ?>
        <input type="hidden" name="redirect" value="<?= htmlspecialchars($_GET['redirect'] ?? '', ENT_QUOTES, 'UTF-8') ?>">
      <?php endif; ?>

      <div class="mb-3">
        <label for="username" class="form-label fw-semibold">Username</label>
        <div class="input-group">
          <span class="input-group-text"><i class="fas fa-user"></i></span>
          <input type="text" class="form-control" id="username" name="username" value="<?= $username ?>" placeholder="Enter your username" required autofocus autocomplete="username">
        </div>
      </div>

      <div class="mb-3">
        <label for="password" class="form-label fw-semibold">Password</label>
        <div class="input-group">
          <span class="input-group-text"><i class="fas fa-lock"></i></span>
          <input type="password" class="form-control" id="password" name="password" placeholder="Enter your password" required autocomplete="current-password">
        </div>
      </div>

      <div class="mb-4">
        <div class="form-check">
          <input class="form-check-input" type="checkbox" id="remember" name="remember" value="1">
          <label class="form-check-label" for="remember">
            Remember me
          </label>
        </div>
      </div>

      <button type="submit" class="btn btn-primary w-100">
        <i class="fas fa-sign-in-alt me-2"></i>Sign In
      </button>
    </form>

    <div class="login-footer">
      &copy; <?= date('Y') ?> eXo Platform SAS
    </div>
  </div>
</body>
</html>
