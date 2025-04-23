<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
$file_path = $_GET['file'];
$log_type = $_GET['type'];
checkCaches();
?>
<html>
<head>
    <?= pageHeader("log visualization"); ?>
    <style>
        #log-output {
            background-color: #f8f8f8;
            border: 1px solid #ccc;
            padding: 10px;
            height: 600px;
            overflow-y: scroll;
            white-space: pre-wrap;
            font-family: monospace;
        }
    </style>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
    <div id="main">
        <div class="container-fluid">
            <div class="row-fluid">
                <div class="span12">
                    <?php
                    // Read file only if the type of file is ok.
                    if (isAuthorizedToReadFile($log_type, $file_path) == true){
                        ?>
                        <div class="instructions">
                            Download file (<?= human_filesize(filesize($file_path), 0); ?>) :
                            <a target="_blank" href="./logsDownload.php?type=<?= $log_type ?>&file=<?= $file_path ?>"><?= $file_path ?></a>
                        </div>
                        <hr/>
                        <?php
                        if (isFileTooLargeToBeViewed($file_path)){
                            echo "<span style=\"color:red\"><strong>This file is too large to be viewed. Please download it.</strong></span>";
                        } else {
                            ?>
                            <pre id="log-output">Loading logs...</pre>
                            <script>
                                let offset = 0;
                                let polling = true;
                                const file = "<?= htmlspecialchars($file_path, ENT_QUOTES) ?>";
                                const type = "<?= htmlspecialchars($log_type, ENT_QUOTES) ?>";

                                function showError(msg) {
                                    const pre = document.getElementById('log-output');
                                    pre.innerHTML += `\n<span style="color: red; font-weight: bold;">[ERROR]</span> ${msg}`;
                                    pre.scrollTop = pre.scrollHeight;
                                }

                                async function fetchLogs() {
                                    if (!polling) return;

                                    try {
                                        const response = await fetch(`logStream.php?file=${encodeURIComponent(file)}&type=${encodeURIComponent(type)}&offset=${offset}`);
                                        if (!response.ok) {
                                            throw new Error(`Server error ${response.status}`);
                                        }

                                        const data = await response.json();

                                        if (data.error) {
                                            showError(data.error);
                                            polling = false; // Stop polling
                                            return;
                                        }

                                        if (data.content) {
                                            const pre = document.getElementById('log-output');
                                            offset = data.offset;
                                            pre.innerHTML += data.content;
                                            pre.scrollTop = pre.scrollHeight;
                                        }

                                    } catch (err) {
                                        showError("Failed to fetch logs: " + err.message);
                                        polling = false; // Stop polling on network/server error
                                    }
                                }

                                setInterval(fetchLogs, 2000);
                            </script>
                            <?php
                        }
                    } else {
                        echo "<span style=\"color:red\"><strong>Not authorized to read this file.</strong></span>";
                    }
                    ?>
                </div>
            </div>
        </div>
        <!-- /container -->
    </div>
</div>
<?php pageFooter(); ?>
</body>
</html>
