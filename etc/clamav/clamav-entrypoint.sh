#!/bin/sh

LOG_FILE=/report/clamav-entrypoint.log
FLAG_FILE=/report/.fullscan_done
REPORT_FILE=/report/clamav-report.txt
LOCK_FILE=/tmp/clamav-report.lock

log() {
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP $1" | tee -a "$LOG_FILE"
}

[ ! -f "$REPORT_FILE" ] && touch "$REPORT_FILE" && chmod 666 "$REPORT_FILE" && log "Report file created" || log "File exists"


# Install inotify-tools if missing
if ! command -v inotifywait >/dev/null 2>&1; then
  log "[Init] Installing inotify-tools..."
  apk add --no-cache inotify-tools
fi

# Start clamd in background
log "[Init] Starting clamd..."
clamd &

# Wait for clamd TCP socket
until nc -z 127.0.0.1 3310 >/dev/null 2>&1; do
  log "[Init] clamd not ready yet..."
  sleep 5
done
log "[Init] clamd is ready."

# Update virus database
log "[Init] Updating virus DB..."
freshclam

# Function to run full scan
full_scan() {
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  log "[Full Scan] Starting full scan..."
  clamdscan --fdpass --multiscan /scan --log=/report/clamav-report-$TIMESTAMP.txt

  # Append full scan log to main incremental log
  (
    flock 200
    cat /report/clamav-report-$TIMESTAMP.txt >> "$REPORT_FILE"
  ) 200>"$LOCK_FILE"

  touch "$FLAG_FILE"
  log "[Full Scan] Done."
}

# Function to run incremental scan using inotify
incremental_scan() {
  log "[Incremental Scan] Watching /scan for new/modified files..."

  inotifywait -m -r -e create -e moved_to -e modify --format "%w%f" /scan |
  while read file; do
      log "[Incremental Scan] Detected new/modified file: $file"
      (
        tmp_log=$(mktemp /tmp/clamav-scan-XXXXXX)
        clamdscan --fdpass --multiscan "$file" > "$tmp_log" 2>&1
        # Append 
        (
          flock 200
          cat "$tmp_log" >> "$REPORT_FILE"
        ) 200>"$LOCK_FILE"
        rm -f "$tmp_log"
      ) &
  done
}

# Run full scan only if not done
if [ ! -f "$FLAG_FILE" ]; then
    full_scan &
else
    log "[Full Scan] Already done, skipping."
fi

# Run incremental scan 
incremental_scan                  