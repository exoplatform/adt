<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';
checkCaches();

if (isset($_GET['clearCaches']) && $_GET['clearCaches'] === 'true') {
    clearCaches();
    header("Location: /debug-caches.php");
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader("Debug Caches"); ?>
</head>
<body>
    <?php pageTracker(); ?>
    <?php pageNavigation(); ?>
    
    <div id="wrap">
        <div id="main">
            <div class="container-fluid">
                <div class="row">
                    <div class="col-12">
                        <div class="card">
                            <div class="card-body">
                                <h1 class="h4 mb-4">Cache Debugging</h1>
                                
                                <div class="list-group mb-4">
                                    <a href="/debug-git.php" class="list-group-item list-group-item-action">
                                        <i class="fas fa-code-branch me-2"></i>Debug Git Functions
                                    </a>
                                    <a href="/debug-deploy.php" class="list-group-item list-group-item-action">
                                        <i class="fas fa-server me-2"></i>Debug Deployment
                                    </a>
                                    <a href="/debug-caches.php" class="list-group-item list-group-item-action active">
                                        <i class="fas fa-database me-2"></i>Debug Caches
                                    </a>
                                    <a href="/debug-caches.php?clearCaches=true" class="list-group-item list-group-item-action list-group-item-danger">
                                        <i class="fas fa-trash-alt me-2"></i>Clear All Caches
                                    </a>
                                </div>
                                
                                <div class="card">
                                    <div class="card-header">
                                        <h2 class="h5 mb-0">Cache Information</h2>
                                    </div>
                                    <div class="card-body">
                                        <?php
                                        if (extension_loaded('apcu') && function_exists('apcu_cache_info')) {
                                            echo '<h3 class="h6">APCu Cache Info</h3>';
                                            echo debug_var(apcu_cache_info(), true);
                                        } elseif (extension_loaded('apc') && function_exists('apc_cache_info')) {
                                            echo '<h3 class="h6">APC Cache Info</h3>';
                                            echo debug_var(apc_cache_info('user'), true);
                                        } elseif (extension_loaded('memcache') && function_exists('memcache_flush')) {
                                            echo '<h3 class="h6">Memcache Info</h3>';
                                            echo debug_var(memcache_flush(), true);
                                        } else {
                                            echo '<div class="alert alert-warning">No supported cache extension found (APCu, APC, or Memcache)</div>';
                                        }
                                        ?>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <?php pageFooter(); ?>
</body>
</html>