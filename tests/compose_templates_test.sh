#!/bin/bash -eu
# Renders the compose project templates (etc/compose/*.j2) for the combinations of database, TLS and certificate, and checks the
# result with `docker compose config` and `nginx -t`. Needs docker and python3-jinja2; nothing is started.
# Usage: tests/compose_templates_test.sh
SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "${WORK}"' EXIT

# a certificate for the TLS cases (the files only have to exist)
openssl req -x509 -newkey rsa:2048 -nodes -keyout "${WORK}/key.pem" -out "${WORK}/cert.pem" -subj /CN=x.test -days 1 2>/dev/null
mkdir -p "${WORK}/letsencrypt/live/x.test"
cp "${WORK}/cert.pem" "${WORK}/letsencrypt/live/x.test/fullchain.pem"
cp "${WORK}/key.pem" "${WORK}/letsencrypt/live/x.test/privkey.pem"

failures=0
# $1 name, then NAME=value overrides of the defaults below
render() {
  local name=$1; shift
  local dir="${WORK}/${name}"
  mkdir -p "${dir}"
  local vars=(
    INSTANCE_KEY=plfent-7.3.0-M16 PRODUCT_NAME=plfent DEPLOYMENT_COMPOSE_PROJECT=adt-plfent-7_3_0-m16-abc123 DEPLOYMENT_ENV_PREFIX=EXO
    DEPLOYMENT_NGINX_TLS=false DEPLOYMENT_HTTP_PORT=40101 DEPLOYMENT_NGINX_IMAGE=nginx DEPLOYMENT_NGINX_IMAGE_VERSION=1.30.2-alpine
    ADT_DATA=/srv/adt ACCEPTANCE_HOST=a.test DEPLOYMENT_CERTBOT_ENABLED=false DEPLOYMENT_CERTBOT_CONFIG_FOLDER="${WORK}/letsencrypt"
    DEPLOYMENT_CERTBOT_DOMAIN=x.test INSTANCE_SSL_CERTIFICATE_FILE="${WORK}/cert.pem" INSTANCE_SSL_CERTIFICATE_KEY_FILE="${WORK}/key.pem"
    DEPLOYMENT_IMAGE=exoplatform/exo-enterprise:7.3.0-M16_0 DEPLOYMENT_PROXY_VHOST=x.test DEPLOYMENT_PROXY_PORT=80 DEPLOYMENT_PROXY_SSL=false
    DEPLOYMENT_JVM_SIZE_MIN=512m DEPLOYMENT_JVM_SIZE_MAX=1g DEPLOYMENT_UPLOAD_MAX_FILE_SIZE=200 DEPLOYMENT_GZIP_ENABLED=false
    DEPLOYMENT_ADDONS=exo-agenda:1.0,exo-jdbc-driver-mysql:2.3.0 DEPLOYMENT_ADDONS_TOREMOVE= DEPLOYMENT_ADDONS_CATALOG=
    DEPLOYMENT_ADDONS_MANAGER_CONFLICT_MODE= DEPLOYMENT_ADDONS_MANAGER_NOCOMPAT_MODE= DEPLOYMENT_PATCHES= DEPLOYMENT_PATCHES_CATALOG=
    DEPLOYMENT_SELFSIGNEDCERTS_HOSTS= DEPLOYMENT_OPTS= DEPLOYMENT_APACHE_HTTPSONLY_ENABLED=false
    DEPLOYMENT_DB_TYPE=MYSQL DEPLOYMENT_DB_ENV_TYPE=mysql DEPLOYMENT_DATABASE_PORT=3306 DEPLOYMENT_DATABASE_NAME=plfent_7_3_0_M16
    DEPLOYMENT_DATABASE_USER=plfent_7_3_x DEPLOYMENT_DATABASE_VERSION=8.4.11
    DEPLOYMENT_ES_IMAGE=elasticsearch DEPLOYMENT_ES_IMAGE_VERSION=9.4.5 DEPLOYMENT_ES_HEAP=512m
    DEPLOYMENT_URL=https://plfent-7.3.0-M16.a.test ETC_DIR=/srv/adt/etc
    # companion services, all off by default
    DEPLOYMENT_MAILPIT_ENABLED=false DEPLOYMENT_MAILPIT_IMAGE=axllent/mailpit DEPLOYMENT_MAILPIT_IMAGE_VERSION=v1.31.6
    DEPLOYMENT_IFRAMELY_ENABLED=false DEPLOYMENT_IFRAMELY_IMAGE=jolt/iframely DEPLOYMENT_IFRAMELY_IMAGE_VERSION=v2.3.0
    DEPLOYMENT_AI_ENABLED=false DEPLOYMENT_AI_IMAGE=ollama/ollama DEPLOYMENT_AI_IMAGE_VERSION=0.32.1 DEPLOYMENT_AI_OLLAMA_MEM_LIMIT=8g
    DEPLOYMENT_AI_OLLAMA_CPU_LIMIT=4 DEPLOYMENT_AI_OLLAMA_NUM_PARALLEL=4 DEPLOYMENT_AI_OLLAMA_KEEP_ALIVE=5m
    DEPLOYMENT_SFTP_ENABLED=false DEPLOYMENT_SFTP_IMAGE=atmoz/sftp DEPLOYMENT_SFTP_IMAGE_VERSION=latest DEPLOYMENT_SFTP_PORT=40199
    DEPLOYMENT_LDAP_ENABLED=false DEPLOYMENT_LDAP_IMAGE=dinkel/openldap DEPLOYMENT_LDAP_IMAGE_VERSION=2.4.44 USER_DIRECTORY=LDAP
    DEPLOYMENT_AD_HOST=localhost DEPLOYMENT_AD_PORT=389 DEPLOYMENT_LDAP_PREPOPULATE_DIR=
    USER_DIRECTORY_BASE_DN=dc=exoplatform,dc=com GROUP_DIRECTORY_BASE_DN= USER_DIRECTORY_ADMIN_DN=cn=admin,dc=exoplatform,dc=com
    USER_DIRECTORY_ADMIN_PASSWORD=exo
    DEPLOYMENT_LAM_ENABLED=false DEPLOYMENT_LAM_IMAGE=ghcr.io/ldapaccountmanager/lam DEPLOYMENT_LAM_IMAGE_VERSION=stable
    DEPLOYMENT_CLOUDBEAVER_ENABLED=false DEPLOYMENT_CLOUDBEAVER_IMAGE=exoplatform/cloudbeaver DEPLOYMENT_CLOUDBEAVER_IMAGE_VERSION=26.2.3-0
    DEPLOYMENT_CLOUDBEAVER_AI_CHAT_DISABLED=true DEPLOYMENT_CLOUDBEAVER_LDAP_HOST=ldap2.exoplatform.org DEPLOYMENT_CLOUDBEAVER_LDAP_PORT=636
    DEPLOYMENT_CLOUDBEAVER_LDAP_SSL=true DEPLOYMENT_CLOUDBEAVER_LDAP_BASE_DN=dc=exoplatform,dc=org DEPLOYMENT_CLOUDBEAVER_LDAP_LOGIN_ATTR=cn
    DEPLOYMENT_CLOUDBEAVER_LDAP_ADMIN_GROUP=cn=admins DEPLOYMENT_CLOUDBEAVER_LDAP_BIND_USER=cn=bind DEPLOYMENT_CLOUDBEAVER_LDAP_BIND_PASSWORD='p$ss'
    DEPLOYMENT_CLAMAV_ENABLED=false DEPLOYMENT_CLAMAV_IMAGE=clamav/clamav DEPLOYMENT_CLAMAV_IMAGE_VERSION=1.5.1
    DEPLOYMENT_MATRIX_ENABLED=false
    DEPLOYMENT_CALDAV_ENABLED=false DEPLOYMENT_CALDAV_IMAGE=ckulka/baikal DEPLOYMENT_CALDAV_IMAGE_VERSION=nginx-php8.2
    DEPLOYMENT_FRONTAIL_ENABLED=false DEPLOYMENT_FRONTAIL_IMAGE=hbenali/frontail DEPLOYMENT_FRONTAIL_IMAGE_VERSION=2.37
  )
  python3 "${SCRIPT_DIR}/tests/render_template.py" "${SCRIPT_DIR}/etc/compose/docker-compose.yml.j2" "${dir}/docker-compose.yml" "${vars[@]}" "$@"
  python3 "${SCRIPT_DIR}/tests/render_template.py" "${SCRIPT_DIR}/etc/compose/nginx.conf.j2" "${dir}/nginx.conf" "${vars[@]}" "$@"
  docker compose --file "${dir}/docker-compose.yml" config --quiet
  local mounts=(--volume "${dir}/nginx.conf:/etc/nginx/nginx.conf:ro")
  if [[ " $* " == *" DEPLOYMENT_NGINX_TLS=true "* ]]; then
    if [[ " $* " == *" DEPLOYMENT_CERTBOT_ENABLED=true "* ]]; then
      mounts+=(--volume "${WORK}/letsencrypt:/etc/letsencrypt:ro")
    else
      mounts+=(--volume "${WORK}/cert.pem:/etc/nginx/certs/fullchain.pem:ro" --volume "${WORK}/key.pem:/etc/nginx/certs/privkey.pem:ro")
    fi
  fi
  docker run --rm "${mounts[@]}" nginx:1.30.2-alpine nginx -t > "${dir}/nginx-test.log" 2>&1 || { cat "${dir}/nginx-test.log"; return 1; }
}
check() { # description, then the arguments of render
  local d=$1; shift
  if render "$@"; then echo "ok   $d"; else echo "FAIL $d"; failures=$((failures+1)); fi
}

check "mysql, plain HTTP"              mysql
check "mariadb, plain HTTP"            mariadb  DEPLOYMENT_DB_TYPE=MARIADB DEPLOYMENT_DATABASE_VERSION=11.4
check "postgres 17, plain HTTP"        pg17     DEPLOYMENT_DB_TYPE=POSTGRES DEPLOYMENT_DB_ENV_TYPE=pgsql DEPLOYMENT_DATABASE_PORT=5432 DEPLOYMENT_DATABASE_VERSION=17
check "postgres 18, plain HTTP"        pg18     DEPLOYMENT_DB_TYPE=POSTGRES DEPLOYMENT_DB_ENV_TYPE=pgsql DEPLOYMENT_DATABASE_PORT=5432 DEPLOYMENT_DATABASE_VERSION=18
check "hsqldb, plain HTTP"             hsqldb   DEPLOYMENT_DB_TYPE=HSQLDB DEPLOYMENT_DB_ENV_TYPE=hsqldb
check "meeds, plain HTTP"              meeds    DEPLOYMENT_ENV_PREFIX=MEEDS PRODUCT_NAME=meeds DEPLOYMENT_IMAGE=meedsio/meeds:7.3.0-M16_0
check "TLS, static certificate"        tls      DEPLOYMENT_NGINX_TLS=true DEPLOYMENT_PROXY_SSL=true DEPLOYMENT_PROXY_PORT=443
check "TLS only, static certificate"   tlsonly  DEPLOYMENT_NGINX_TLS=true DEPLOYMENT_PROXY_SSL=true DEPLOYMENT_PROXY_PORT=443 DEPLOYMENT_APACHE_HTTPSONLY_ENABLED=true
check "TLS, certbot certificate"       certbot  DEPLOYMENT_NGINX_TLS=true DEPLOYMENT_CERTBOT_ENABLED=true DEPLOYMENT_PROXY_SSL=true DEPLOYMENT_PROXY_PORT=443
check "options with quotes and dollar" options  DEPLOYMENT_OPTS='-Dfoo="$bar" -Dx=1' DEPLOYMENT_ADDONS_CATALOG=https://x.test/catalog.json DEPLOYMENT_PATCHES=p1:1 DEPLOYMENT_PATCHES_CATALOG=https://x.test/p.json DEPLOYMENT_ADDONS_TOREMOVE=exo-a

# every companion service alone, then all together (TLS, PostgreSQL), each with its nginx locations
check "mailpit"      c-mailpit      DEPLOYMENT_MAILPIT_ENABLED=true
check "iframely"     c-iframely     DEPLOYMENT_IFRAMELY_ENABLED=true
check "ai (ollama)"  c-ai           DEPLOYMENT_AI_ENABLED=true
check "sftp"         c-sftp         DEPLOYMENT_SFTP_ENABLED=true
check "ldap"         c-ldap         DEPLOYMENT_LDAP_ENABLED=true
check "ldap (external server)" c-ldapext DEPLOYMENT_LDAP_ENABLED=true USER_DIRECTORY=MSAD
check "ldap + lam"   c-lam          DEPLOYMENT_LDAP_ENABLED=true DEPLOYMENT_LAM_ENABLED=true
check "cloudbeaver"  c-cloudbeaver  DEPLOYMENT_CLOUDBEAVER_ENABLED=true
check "clamav"       c-clamav       DEPLOYMENT_CLAMAV_ENABLED=true
check "caldav"       c-caldav       DEPLOYMENT_CALDAV_ENABLED=true
check "frontail"     c-frontail     DEPLOYMENT_FRONTAIL_ENABLED=true
check "all of them, TLS, PostgreSQL" c-all DEPLOYMENT_NGINX_TLS=true DEPLOYMENT_PROXY_SSL=true DEPLOYMENT_PROXY_PORT=443 \
  DEPLOYMENT_DB_TYPE=POSTGRES DEPLOYMENT_DB_ENV_TYPE=pgsql DEPLOYMENT_DATABASE_PORT=5432 DEPLOYMENT_DATABASE_VERSION=17 \
  DEPLOYMENT_MAILPIT_ENABLED=true DEPLOYMENT_IFRAMELY_ENABLED=true DEPLOYMENT_AI_ENABLED=true DEPLOYMENT_SFTP_ENABLED=true \
  DEPLOYMENT_LDAP_ENABLED=true DEPLOYMENT_LAM_ENABLED=true DEPLOYMENT_CLOUDBEAVER_ENABLED=true DEPLOYMENT_CLAMAV_ENABLED=true \
  DEPLOYMENT_CALDAV_ENABLED=true DEPLOYMENT_FRONTAIL_ENABLED=true

grep -q 'JAVA_OPTS: "-Dfoo=\\"\$\$bar\\" -Dx=1"' "${WORK}/options/docker-compose.yml" && echo "ok   a dollar in a value is escaped for compose" || { echo "FAIL dollar escaping"; failures=$((failures+1)); }
grep -q 'container_name: "plfent-7.3.0-M16_exo"' "${WORK}/mysql/docker-compose.yml" && echo "ok   containers are named after the instance key" || { echo "FAIL container names"; failures=$((failures+1)); }
# what a companion adds to the application and what it needs before it starts
c=${WORK}/c-all/docker-compose.yml
for opt in "-Dio.meeds.iframely.url=https://plfent-7.3.0-M16.a.test/oembed" "-Dmeeds.ai.ollama.url=http://ollama:11434" "-Dexo.addons.lecko.SftpHost=sftp" \
           "-Dexo.ldap.url=ldap://ldap:389" "-Dexo.malwareDetection.connector.clamav.isDefault=true" "-Dexo.agenda.caldav.connector.enabled=true"; do
  grep -qF -- "${opt}" "${c}" && echo "ok   the application gets ${opt%%=*}" || { echo "FAIL missing ${opt}"; failures=$((failures+1)); }
done
for svc in mailpit iframely ollama sftp ldap lam cloudbeaver clamav baikal frontail; do
  grep -q "^  ${svc}:" "${c}" && echo "ok   service ${svc}" || { echo "FAIL service ${svc} missing"; failures=$((failures+1)); }
done
grep -q 'EXO_MAIL_SMTP_HOST: "mailpit"' "${c}" && echo "ok   mail goes to mailpit" || { echo "FAIL mail host"; failures=$((failures+1)); }
grep -q 'clamav_report:/clamav/report' "${c}" && echo "ok   the application reads the clamav report" || { echo "FAIL clamav report"; failures=$((failures+1)); }
! grep -q '^  mailpit:' "${WORK}/mysql/docker-compose.yml" && ! grep -q 'location.*mailpit' "${WORK}/mysql/nginx.conf" && echo "ok   no companion when none is enabled" || { echo "FAIL a companion is present"; failures=$((failures+1)); }
grep -q 'location /lam/' "${WORK}/c-all/nginx.conf" && grep -q 'location /baikal' "${WORK}/c-all/nginx.conf" && echo "ok   nginx locations of the companions" || { echo "FAIL locations"; failures=$((failures+1)); }
! grep -q 'db:' "${WORK}/hsqldb/docker-compose.yml" && echo "ok   hsqldb has no database container" || { echo "FAIL hsqldb has a db"; failures=$((failures+1)); }
grep -qx '      - db:/var/lib/postgresql' "${WORK}/pg18/docker-compose.yml" && grep -qx '      - db:/var/lib/postgresql/data' "${WORK}/pg17/docker-compose.yml" && echo "ok   postgres 18 keeps its data one level up" || { echo "FAIL postgres volume paths"; failures=$((failures+1)); }

[ ${failures} -eq 0 ] && echo "All tests passed" || { echo "${failures} failure(s)"; exit 1; }
