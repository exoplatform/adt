#!/bin/bash

RECORDINGS_DIR=$1
# /config/logs on the legacy image, /storage/logs (the only writable dir) on the rootless one
LOG_DIR=${JIBRI_LOGS_DIR:-/config/logs}
mkdir -p "$LOG_DIR"
echo "[debug] CALL APP URL: $CALL_APP_URL" >> $LOG_DIR/finalize.log
echo "[debug] EXO_JWT_SECRET: $EXO_JWT_SECRET" >> $LOG_DIR/finalize.log

# Build JWT
jwt_header=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 -w 0 | sed s/\+/-/g | sed 's/\//_/g' | sed -E s/=+$//)

payloadJson='{"action":"external_auth"}'
payload=$(echo -n "$payloadJson" | base64 -w 0 | sed s/\+/-/g | sed 's/\//_/g' | sed -E s/=+$//)

# Calculate signature directly using the secret string
hmac_signature=$(echo -n "${jwt_header}.${payload}" | openssl dgst -sha256 -hmac "$EXO_JWT_SECRET" -binary | base64 -w 0 | sed s/\+/-/g | sed 's/\//_/g' | sed -E s/=+$//)

jwt="${jwt_header}.${payload}.${hmac_signature}"

echo "[debug] Generated JWT: $jwt" >> $LOG_DIR/finalize.log

files=( $RECORDINGS_DIR/*.mp4 )
recording=$(basename ${files[0]})
callId=${recording%_*}

link=$(curl -o --write-out ' %{http_code}' --silent -k -X GET -H "X-Exoplatform-External-Auth: ${jwt}" "$CALL_APP_URL/api/v1/calls/${callId}/uploadLink")
timestamp=$(date +%F_%T)

if [ -n "$link" ]; then
    resp=$(curl -i --write-out '%{http_code}' --silent --output /dev/null -k -X POST -H "Content-Type: multipart/form-data" -H "X-Exoplatform-Auth: ${jwt}" -F "file=@${files[0]}" "$link")
    if [ $resp == 200 ]; then
        echo "[$timestamp] Uploaded recording ${files[0]} to eXo Platform" >> $LOG_DIR/finalize.log
        rm -rf $RECORDINGS_DIR
        echo "[$timestamp] Removed folder $RECORDINGS_DIR" >> $LOG_DIR/finalize.log
    else 
        echo "[$timestamp] Couldn't upload recording ${files[0]} to eXo Platform. HTTP_CODE: $resp" >> $LOG_DIR/finalize.log
    fi
else 
    echo "[$timestamp] Couldn't get upload link for recording ${files[0]}" >> $LOG_DIR/finalize.log
fi
exit 0