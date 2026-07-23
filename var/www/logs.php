<!DOCTYPE html>
<?php
require_once(dirname(__FILE__) . '/lib/functions.php');
require_once(dirname(__FILE__) . '/lib/functions-ui.php');
$file_path = $_GET['file'] ?? '';
$log_type = $_GET['type'] ?? '';
checkCaches();
?>
<html lang="en">
<head>
<?= pageHeader("log visualization", false); ?>
</head>
<body>
<?php pageTracker(); ?>
<?php pageNavigation(); ?>
<!-- Main ================================================== -->
<div id="wrap">
    <div id="main" role="main">
        <div class="container-fluid">
            <div class="row">
                <div class="col-12">
                    <div class="page-header">
                        <h1 class="page-header__title">Log Viewer</h1>
                        <p class="page-header__subtitle text-mono"><?= htmlspecialchars($file_path) ?></p>
                    </div>
                    <?php
                        // Read file only if the type of file is ok.
                        if (isAuthorizedToReadFile($log_type, $file_path) == true){
                            $tooLarge = isFileTooLargeToBeViewed($file_path);
                            $startOffset = filesize($file_path);
                    ?>
                        <div class="log-toolbar mb-2 d-flex align-items-center flex-wrap gap-2">
                            <a href="./logsDownload.php?type=<?= urlencode($log_type) ?>&file=<?= urlencode($file_path) ?>" target="_blank"
                               class="btn btn-sm btn-outline-success" title="Download <?= htmlspecialchars(basename($file_path)) ?>">
                                <i class="fas fa-download me-1"></i>Download <span class="text-muted">(<?= human_filesize(filesize($file_path), 0) ?>)</span>
                            </a>
                            <div class="vr mx-1 d-none d-md-block"></div>
                            <button id="tailStart" type="button" class="btn btn-sm btn-outline-primary" disabled>
                                <i class="fas fa-play me-1"></i>Start
                            </button>
                            <button id="tailPause" type="button" class="btn btn-sm btn-outline-secondary">
                                <i class="fas fa-pause me-1"></i>Pause
                            </button>
                            <span id="tailStatus" class="log-status log-status--live">
                                <span class="log-status__dot"></span>Live
                            </span>
                            <div class="form-check form-switch ms-2 mb-0">
                                <input class="form-check-input" type="checkbox" id="autoscroll" checked>
                                <label class="form-check-label" for="autoscroll">Autoscroll</label>
                            </div>
                            <div class="log-filter ms-2 d-flex align-items-center gap-2">
                                <i class="fas fa-filter text-muted"></i>
                                <input type="text" id="logFilter" class="form-control form-control-sm" placeholder="Filter lines…" style="width: 220px;">
                            </div>
                            <button id="clearTail" type="button" class="btn btn-sm btn-outline-secondary ms-auto">
                                <i class="fas fa-eraser me-1"></i>Clear
                            </button>
                        </div>
                    <?php
                            if ($tooLarge){
                                echo "<div class='alert alert-warning'><i class='fas fa-exclamation-triangle me-2'></i><strong>This file is too large to be fully displayed.</strong> Download it to see its full history, or use <strong>Live Tail</strong> above to stream new lines as they are written.</div>";
                                echo "<div class='code log-viewer'><div class='mb-0' id='logContent'></div></div>";
                            } else {
                                echo "<div class='code log-viewer'><div class='mb-0' id='logContent'>";
                                $data = file_get_contents($file_path);
                                echo ansiToHtml(htmlspecialchars($data, ENT_NOQUOTES, 'UTF-8'));
                                echo "</div></div>";
                            }
                    ?>
                        <script>
                        (function() {
                            var logType = <?= json_encode($log_type) ?>;
                            var logFile = <?= json_encode($file_path) ?>;
                            var offset = <?= json_encode($startOffset) ?>;
                            var pollMs = 3000;
                            var timer = null;
                            var pendingLine = '';
                            var content = document.getElementById('logContent');
                            var startBtn = document.getElementById('tailStart');
                            var pauseBtn = document.getElementById('tailPause');
                            var statusEl = document.getElementById('tailStatus');
                            var autoscroll = document.getElementById('autoscroll');
                            var filterInput = document.getElementById('logFilter');
                            var container = content.closest('.log-viewer');

                            // Size the viewer to exactly fill the remaining space inside #wrap
                            // (which already excludes the footer), instead of a fixed vh
                            // fraction, so the page never scrolls more than it has to.
                            function resizeViewer() {
                                if (!container) return;
                                var mainEl = document.getElementById('main');
                                var wrapEl = document.getElementById('wrap');
                                var bottomPad = mainEl ? parseFloat(getComputedStyle(mainEl).paddingBottom) || 0 : 0;
                                var top = container.getBoundingClientRect().top;
                                var bottomLimit = wrapEl ? wrapEl.getBoundingClientRect().bottom : window.innerHeight;
                                var available = bottomLimit - top - bottomPad;
                                container.style.maxHeight = Math.max(200, available) + 'px';
                            }
                            window.addEventListener('resize', resizeViewer);
                            resizeViewer();

                            function setStatus(live) {
                                statusEl.className = 'log-status ' + (live ? 'log-status--live' : 'log-status--paused');
                                statusEl.innerHTML = '<span class="log-status__dot"></span>' + (live ? 'Live' : 'Paused');
                                startBtn.disabled = live;
                                pauseBtn.disabled = !live;
                            }

                            function scrollToBottom() {
                                if (autoscroll.checked && container) {
                                    container.scrollTop = container.scrollHeight;
                                }
                            }

                            // Wrap complete lines in <div class="log-line"> so they can be
                            // individually shown/hidden by the filter box. Incomplete trailing
                            // lines are buffered until the rest of the line arrives.
                            function appendHtml(html) {
                                if (!html) return;
                                var combined = pendingLine + html;
                                var parts = combined.split('\n');
                                pendingLine = parts.pop();
                                if (parts.length === 0) return;
                                var query = filterInput.value.trim().toLowerCase();
                                var frag = parts.map(function(line) {
                                    var hidden = query && line.toLowerCase().indexOf(query) === -1;
                                    return '<div class="log-line' + (hidden ? ' log-line--hidden' : '') + '">' + line + '</div>';
                                }).join('');
                                content.insertAdjacentHTML('beforeend', frag);
                            }

                            function applyFilter() {
                                var query = filterInput.value.trim().toLowerCase();
                                content.querySelectorAll('.log-line').forEach(function(el) {
                                    if (!query) {
                                        el.classList.remove('log-line--hidden');
                                        return;
                                    }
                                    var match = el.textContent.toLowerCase().indexOf(query) !== -1;
                                    el.classList.toggle('log-line--hidden', !match);
                                });
                            }

                            var filterDebounce = null;
                            filterInput.addEventListener('input', function() {
                                clearTimeout(filterDebounce);
                                filterDebounce = setTimeout(applyFilter, 150);
                            });

                            function poll() {
                                var url = './logsTail.php?type=' + encodeURIComponent(logType) +
                                    '&file=' + encodeURIComponent(logFile) + '&offset=' + offset;
                                fetch(url).then(function(r) { return r.json(); }).then(function(json) {
                                    if (json.error) {
                                        stop();
                                        return;
                                    }
                                    if (json.truncated) {
                                        content.innerHTML = '';
                                        pendingLine = '';
                                    }
                                    if (json.skipped > 0) {
                                        content.insertAdjacentHTML('beforeend', '<div class="log-gap">--- ' + json.skipped + ' bytes skipped ---</div>');
                                    }
                                    if (json.data) {
                                        appendHtml(json.data);
                                        scrollToBottom();
                                    }
                                    offset = json.size;
                                }).catch(function() {
                                    // transient network error: keep retrying on next tick
                                });
                            }

                            function start() {
                                if (timer) return;
                                poll();
                                timer = setInterval(poll, pollMs);
                                setStatus(true);
                            }

                            function stop() {
                                if (timer) { clearInterval(timer); timer = null; }
                                setStatus(false);
                            }

                            startBtn.addEventListener('click', start);
                            pauseBtn.addEventListener('click', stop);

                            document.getElementById('clearTail').addEventListener('click', function() {
                                content.innerHTML = '';
                                pendingLine = '';
                            });

                            var wasLiveBeforeHidden = false;
                            document.addEventListener('visibilitychange', function() {
                                if (document.hidden) {
                                    wasLiveBeforeHidden = !!timer;
                                    stop();
                                } else if (wasLiveBeforeHidden) {
                                    start();
                                }
                            });

                            // Re-wrap the server-rendered initial content into filterable lines.
                            var initialHtml = content.innerHTML;
                            content.innerHTML = '';
                            appendHtml(initialHtml);

                            start();
                        })();
                        </script>
                    <?php
                        } else {
                            echo "<div class='alert alert-danger'><i class='fas fa-ban me-2'></i><strong>Not authorized to read this file.</strong></div>";
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