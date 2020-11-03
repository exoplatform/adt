#!/bin/bash

RECORDINGS_DIR=$1
# Put this script to .jitsi-meet-cfg/jibri (config folder) as finalize.sh
# Need to setup $CALL_APP_URL and $EXO_JWT_TOKEN as ENV variable before running
echo "[debug] CALL APP URL: $CALL_APP_URL" >> /config/logs/finalize.log
echo "[debug] EXO_JWT_TOKEN: $EXO_JWT_TOKEN" >> /config/logs/finalize.log

# Attempt to build JWT
#currentTime=$(date +%s)
# expires in 3 minutes
#expires=$(($currentTime + 18000));
# Construct the header
#jwt_header=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64 | sed s/\+/-/g | sed 's/\//_/g' | sed -E s/=+$//)
#payloadJson="{\"action\":\"external_auth\", \"exp\": ${expires}}"
# Construct the payload
#payload=$(echo -n $payloadJson | base64 | sed s/\+/-/g |sed 's/\//_/g' |  sed -E s/=+$//)
# Convert secret to hex (not base64)
#hexsecret=$(echo -n "$EXO_JWT_SECRET" | xxd -p | paste -sd "")
# Calculate hmac signature -- note option to pass in the key as hex bytes
#hmac_signature=$(echo -n "${jwt_header}.${payload}" |  openssl dgst -sha256 -mac HMAC -macopt hexkey:$hexsecret -binary | base64  | sed s/\+/-/g | sed 's/\//_/g' | sed -E s/=+$//)
# Create the full token
#jwt="${jwt_header}.${payload}.${hmac_signature}"

files=( $RECORDINGS_DIR/*.mp4 )
recording=$(basename ${files[0]})
callId=${recording%_*}
#Push the recording to Jitsi Call App
# --write-out '%{http_code}' --silent --output /dev/null
link=$(curl -o --write-out ' %{http_code}' --silent -k -X  GET -H "X-Exoplatform-External-Auth: ${EXO_JWT_TOKEN}" $CALL_APP_URL/api/v1/calls/${callId}/uploadLink)
timestamp=$(date +%F_%T)
if [ -n "$link" ]; then
	resp=$(curl -i --write-out '%{http_code}' --silent --output /dev/null -k -X  POST -H "Content-Type: multipart/form-data" -H "X-Exoplatform-Auth: ${EXO_JWT_TOKEN}" -F "file=@${files[0]}" $link)
	if [ $resp == 200 ]; then
		echo "[$timestamp] Uploaded recording ${files[0]} to eXo Platform" >> /config/logs/finalize.log
		rm -rf $RECORDINGS_DIR
		echo "[$timestamp] Removed folder $RECORDINGS_DIR" >> /config/logs/finalize.log
	else 
		echo "[$timestamp] Couldn't upload recording ${files[0]} to eXo Platform. HTTP_CODE: $resp" >> /config/logs/finalize.log
	fi
else 
	echo "[$timestamp] Couldn't get upload link for recording ${files[0]}" >> /config/logs/finalize.log
fi
exit 0