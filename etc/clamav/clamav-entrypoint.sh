#!/bin/sh

LOG_FILE=/report/clamav-entrypoint.log
FLAG_FILE=/report/.fullscan_done
REPORT_FILE=/report/clamav-report.txt
LOCK_FILE=/tmp/clamav-report.lock

LOG_DIR="/var/log/clamav"
REPORT_DIR="/report"
TMP_DIR="/tmp"
VAR_DIR="/var/lib/clamav"
USER_NAME="prdacc"
USER_ID=12000
GROUP_ID=12000

log() {
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP $1" | tee -a "$LOG_FILE"
}

# Install inotify-tools if missing
if ! command -v inotifywait >/dev/null 2>&1; then
  log "[Init] Installing inotify-tools..."
  apk add --no-cache inotify-tools
fi

# Create user prdacc if missing
if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
  log "[Init] Creating user ${USER_NAME} (uid=${USER_ID}, gid=${GROUP_ID})..."
  addgroup -g "${GROUP_ID}" "${USER_NAME}" || true
  adduser -D -u "${USER_ID}" -G "${USER_NAME}" -s /bin/sh "${USER_NAME}" || true
fi

# Ensure directories exist and are writable
for dir in "$LOG_DIR" "$REPORT_DIR" "$TMP_DIR" "$VAR_DIR"; do
  mkdir -p "$dir"
  chown -R "${USER_ID}:${GROUP_ID}" "$dir"
done

[ ! -f "$REPORT_FILE" ] && touch "$REPORT_FILE" && chmod 666 "$REPORT_FILE" && log "Report file created" || log "File exists"

exec tini -- su -s /bin/sh $USER_NAME -c '
  log() {
      TIMESTAMP=$(date +"%Y-%m-%d--%H-%M-%S")
      echo "$TIMESTAMP $1" | tee -a "'"$LOG_FILE"'"
  }

  # Start clamd in background
  log "[Init] Starting clamd..."
  /usr/sbin/clamd &

  # Wait for clamd TCP socket
  until nc -z 127.0.0.1 3310 >/dev/null 2>&1; do
    log "[Init] clamd not ready yet..."
    sleep 5
  done
  log "[Init] clamd is ready."

  # Update virus database
  log "[Init] Updating virus DB..."
  /usr/bin/freshclam

  # Full scan function
  full_scan() {
    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    log "[Full Scan] Starting full scan..."
    clamdscan --fdpass --multiscan /scan --log=/report/clamav-report-$TIMESTAMP.txt
    ( flock 200; cat /report/clamav-report-$TIMESTAMP.txt >> "'"$REPORT_FILE"'" ) 200>"'"$LOCK_FILE"'"
    touch "'"$FLAG_FILE"'"
    log "[Full Scan] Done."
  }

  # Incremental scan function
  incremental_scan() {
    log "[Incremental Scan] Watching /scan for new/modified files..."

    WATCH_DIRS="/scan/files /scan/jcr/values"
    if [ -d "/scan/synapse/media" ]; then
      WATCH_DIRS="$WATCH_DIRS /scan/synapse/media"
    fi

    # Check if Dir exist
    for dir in $WATCH_DIRS; do
      while [ ! -d "$dir" ]; do
        echo "[Incremental Scan] Waiting for $dir to be created..."
        sleep 2
      done
    done

    inotifywait -m -r -e create -e moved_to -e modify --format "%w%f" $WATCH_DIRS |
    while read file; do
        log "[Incremental Scan] Detected new/modified file: $file"
        (
          tmp_log=$(mktemp /tmp/clamav-scan-XXXXXX)
          clamdscan --fdpass --multiscan "$file" > "$tmp_log" 2>&1
          ( flock 200; cat "$tmp_log" >> "'"$REPORT_FILE"'" ) 200>"'"$LOCK_FILE"'"
          rm -f "$tmp_log"
        ) &
    done
  }

  # Run full scan once
  if [ ! -f "'"$FLAG_FILE"'" ]; then
      full_scan &
  else
      log "[Full Scan] Already done, skipping."
  fi

  # Run incremental scan
  incremental_scan
'