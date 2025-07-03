<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/functions.php';
require_once __DIR__ . '/lib/functions-ui.php';

$file_path = $_GET['file'] ?? '';
$log_type = $_GET['type'] ?? '';
checkCaches();

if (!isAuthorizedToReadFile($log_type, $file_path)) {
    header("HTTP/1.1 403 Forbidden");
    exit("Not authorized to read this file.");
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <?php pageHeader("Log Visualization"); ?>
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
                                <div class="d-flex justify-content-between align-items-center mb-3">
                                    <h1 class="h4 mb-0">Log File Viewer</h1>
                                    <a href="./logsDownload.php?type=<?= htmlspecialchars($log_type) ?>&file=<?= htmlspecialchars($file_path) ?>" 
                                       class="btn btn-primary btn-sm" 
                                       download>
                                        <i class="fas fa-download me-1"></i>Download
                                        (<?= human_filesize(filesize($file_path), 0) ?>)
                                    </a>
                                </div>
                                
                                <hr>
                                
                                <?php if (isFileTooLargeToBeViewed($file_path)): ?>
                                    <div class="alert alert-warning">
                                        <strong>File too large to view:</strong> Please download the file to view its contents.
                                    </div>
                                <?php else: ?>
                                    <div class="log-display">
                                        <pre><?= htmlspecialchars(file_get_contents($file_path), ENT_NOQUOTES, 'UTF-8') ?></pre>
                                    </div>
                                <?php endif; ?>
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