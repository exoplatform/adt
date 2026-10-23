(function() {
    var data = document.getElementById('logData');
    var logType = data.getAttribute('data-type');
    var logFile = data.getAttribute('data-file');
    var offset = parseInt(data.getAttribute('data-offset'), 10);
    var pollMs = 3000;
    var timer = null;
    var pendingLine = '';
    var content = document.getElementById('logContent');
    var startBtn = document.getElementById('tailStart');
    var pauseBtn = document.getElementById('tailPause');
    var statusEl = document.getElementById('tailStatus');
    var autoscroll = document.getElementById('autoscroll');
    var filterInput = document.getElementById('logFilter');
    var scrollBox = content.closest('.log-viewer__scroll');
    var outerBox = content.closest('.log-viewer');
    var panel = document.getElementById('logPanel');
    var fullscreenBtn = document.getElementById('fullscreenToggle');
    var isFullscreen = false;

    // Size the viewer to fill the remaining space above the footer,
    // leaving a visible gap so the footer is never hidden below the
    // fold. Measured from window/footer/top directly (not from #wrap's
    // own rect) to avoid a feedback loop: #wrap's height depends on the
    // viewer's current height, so using it as the reference would make
    // the viewer grow a little more on every call.
    var GAP_BEFORE_FOOTER = 16;
    function resizeViewer() {
        if (!outerBox) return;
        if (isFullscreen) {
            outerBox.style.maxHeight = '';
            return;
        }
        var mainEl = document.getElementById('main');
        var footerEl = document.getElementById('footer');
        var bottomPad = mainEl ? parseFloat(getComputedStyle(mainEl).paddingBottom) || 0 : 0;
        var footerH = footerEl ? footerEl.getBoundingClientRect().height : 0;
        var top = outerBox.getBoundingClientRect().top;
        var available = window.innerHeight - top - footerH - bottomPad - GAP_BEFORE_FOOTER;
        outerBox.style.maxHeight = Math.max(200, available) + 'px';
    }
    window.addEventListener('resize', resizeViewer);
    resizeViewer();
    // Re-measure once things settle post-load (web fonts, scrollbar
    // gutter, etc. can shift layout slightly after the first paint).
    function resettleViewer() {
        resizeViewer();
        scrollToBottom();
    }
    window.addEventListener('load', resettleViewer);
    if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(resettleViewer);
    }

    function toggleFullscreen() {
        isFullscreen = !isFullscreen;
        panel.classList.toggle('log-fullscreen', isFullscreen);
        document.body.classList.toggle('log-fullscreen-active', isFullscreen);
        fullscreenBtn.innerHTML = isFullscreen ? '<i class="fas fa-compress"></i>' : '<i class="fas fa-expand"></i>';
        fullscreenBtn.title = isFullscreen ? 'Exit full screen' : 'Expand to full screen';
        resizeViewer();
        scrollToBottom();
    }
    fullscreenBtn.addEventListener('click', toggleFullscreen);
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && isFullscreen) toggleFullscreen();
    });

    function setStatus(live) {
        statusEl.className = 'log-status ' + (live ? 'log-status--live' : 'log-status--paused');
        statusEl.innerHTML = '<span class="log-status__dot"></span>' + (live ? 'Live' : 'Paused');
        startBtn.disabled = live;
        pauseBtn.disabled = !live;
    }

    function scrollToBottom() {
        if (autoscroll.checked && scrollBox) {
            scrollBox.scrollTop = scrollBox.scrollHeight;
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
        var url = './logsTail?type=' + encodeURIComponent(logType) +
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
            showSize(json.size);
        }).catch(function() {
            // transient network error: keep retrying on next tick
        });
    }

    // Keep the "Download (size)" label in step with the file while it grows. The unit follows the number of
    // digits of the byte count, as in the label rendered at page load (4247 B -> "4K", 89 B -> "89B").
    function showSize(bytes) {
        var el = document.getElementById('dlSize');
        if (!el || typeof bytes !== 'number') return;
        var factor = Math.floor((String(bytes).length - 1) / 3);
        el.textContent = '(' + (bytes / Math.pow(1024, factor)).toFixed(0) + 'BKMGTP'.charAt(factor) + ')';
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

    // Always open scrolled to the most recent entries, not the start
    // of the file.
    scrollBox.scrollTop = scrollBox.scrollHeight;

    start();
})();
