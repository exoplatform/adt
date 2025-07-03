<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';
checkCaches();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader("Debug"); ?>
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
                                <h1 class="h4 mb-4">Debug Tools</h1>
                                
                                <div class="list-group mb-4">
                                    <a href="/debug-git.php" class="list-group-item list-group-item-action">
                                        <i class="fas fa-code-branch me-2"></i>Debug Git Functions
                                    </a>
                                    <a href="/debug-deploy.php" class="list-group-item list-group-item-action">
                                        <i class="fas fa-server me-2"></i>Debug Deployment
                                    </a>
                                    <a href="/debug-caches.php" class="list-group-item list-group-item-action">
                                        <i class="fas fa-database me-2"></i>Debug Caches
                                    </a>
                                    <a href="/debug-caches.php?clearCaches=true" class="list-group-item list-group-item-action list-group-item-danger">
                                        <i class="fas fa-trash-alt me-2"></i>Clear All Caches
                                    </a>
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