#!/bin/sh
#
# Copyright (C) 2003-2013 eXo Platform SAS.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.
#

# -----------------------------------------------------------------------------
# Load environment specific settings
# -----------------------------------------------------------------------------
[ -e ${CATALINA_HOME}/bin/setenv-local.sh ] && . ${CATALINA_HOME}/bin/setenv-local.sh

# -----------------------------------------------------------------------------
# Update CATALINA_OPTS entries
# -----------------------------------------------------------------------------
# JVM
CATALINA_OPTS="${CATALINA_OPTS} -XX:+HeapDumpOnOutOfMemoryError"
CATALINA_OPTS="${CATALINA_OPTS} -XX:HeapDumpPath=${CATALINA_HOME}/logs/"
# JMX
CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote=true"
CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.ssl=false"
CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.password.file=${CATALINA_HOME}/conf/jmxremote.password"
CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote.access.file=${CATALINA_HOME}/conf/jmxremote.access"
CATALINA_OPTS="${CATALINA_OPTS} -Djava.rmi.server.hostname=${EXO_JVM_JMX_REMOTE_HOSTNAME}"
# CRaSH
if ${DEPLOYMENT_CRASH_ENABLED}; then
    CATALINA_OPTS="${CATALINA_OPTS} -Dcrash.telnet.port=${EXO_CRASH_TELNET_PORT}"
    CATALINA_OPTS="${CATALINA_OPTS} -Dcrash.ssh.port=${EXO_CRASH_SSH_PORT}"
fi
# Elasticsearch Embedded
if ${DEPLOYMENT_ES_ENABLED}; then
    CATALINA_OPTS="${CATALINA_OPTS} -Dexo.es.embedded.enabled=${DEPLOYMENT_ES_EMBEDDED}"
    CATALINA_OPTS="${CATALINA_OPTS} -Des.http.port=${EXO_ES_HTTP_PORT}"
    CATALINA_OPTS="${CATALINA_OPTS} -Dexo.es.index.server.url=http://127.0.0.1:${EXO_ES_HTTP_PORT}"
    CATALINA_OPTS="${CATALINA_OPTS} -Dexo.es.search.server.url=http://127.0.0.1:${EXO_ES_HTTP_PORT}"
    CATALINA_OPTS="${CATALINA_OPTS} -Des.path.data=${CATALINA_HOME}/${EXO_ES_PATH_DATA}"
    CATALINA_OPTS="${CATALINA_OPTS} -Des.node.name=${INSTANCE_KEY}"
fi
# eXo Addon Chat
if ${DEPLOYMENT_CHAT_ENABLED}; then
    if ! ${DEPLOYMENT_CHAT_EMBEDDED}; then
        CATALINA_OPTS="${CATALINA_OPTS} -Dchat.standaloneChatServer=true"
        CATALINA_OPTS="${CATALINA_OPTS} -Dchat.chatServerBase=http://localhost:${DEPLOYMENT_CHAT_SERVER_PORT}"
    else
        CATALINA_OPTS="${CATALINA_OPTS} -Dchat.dbServerHost=${EXO_CHAT_MONGODB_HOSTNAME}"
        CATALINA_OPTS="${CATALINA_OPTS} -Dchat.dbServerPort=${EXO_CHAT_MONGODB_PORT}"
    fi
    CATALINA_OPTS="${CATALINA_OPTS} -Dchat.dbName=${EXO_CHAT_MONGODB_NAME}"
    CATALINA_OPTS="${CATALINA_OPTS} -Dchat.chatPassPhrase=${EXO_CHAT_MONGODB_NAME}"
fi

# eXo Onlyoffice addon
if ${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_ENABLED}; then
    if ${DEPLOYMENT_APACHE_HTTPS_ENABLED}; then
        DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_SCHEME=https
    else
        DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_SCHEME=http
    fi
    if [ -n "${DEPLOYMENT_APACHE_VHOST_ALIAS}" ]; then
        DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_HOST="${DEPLOYMENT_APACHE_VHOST_ALIAS}"
    else
        DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_HOST="${INSTANCE_KEY}.${ACCEPTANCE_HOST}"
    fi
    CATALINA_OPTS="${CATALINA_OPTS} -Donlyoffice.documentserver.host=${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_HOST}"
    CATALINA_OPTS="${CATALINA_OPTS} -Donlyoffice.documentserver.schema=${DEPLOYMENT_ONLYOFFICE_DOCUMENTSERVER_SCHEME}"
    CATALINA_OPTS="${CATALINA_OPTS} -Donlyoffice.documentserver.allowedhosts=localhost,${INSTANCE_KEY}.${ACCEPTANCE_HOST},${DEPLOYMENT_APACHE_VHOST_ALIAS}"
    CATALINA_OPTS="${CATALINA_OPTS} -Donlyoffice.documentserver.accessOnly=false"
fi

#LDAP 6.x integration
if ${DEPLOYMENT_LDAP_ENABLED}; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.ldap.type=ldap" 
  [ ! -z "${DEPLOYMENT_LDAP_PORT}" ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.ldap.url=ldap://localhost:${DEPLOYMENT_LDAP_PORT}"
  [ ! -z "${USER_DIRECTORY_ADMIN_DN}" ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.ldap.admin.dn=\"${USER_DIRECTORY_ADMIN_DN}\""
  [ ! -z "${USER_DIRECTORY_ADMIN_PASSWORD}" ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.ldap.admin.password=\"${USER_DIRECTORY_ADMIN_PASSWORD}\""
  [ ! -z "${USER_DIRECTORY_BASE_DN}" ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.ldap.users.base.dn=\"ou=People,o=portal,o=gatein,${USER_DIRECTORY_BASE_DN}\""
  #Even when no groups sync, We have to override the value and set it to empty
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.ldap.groups.base.dn=\"${GROUP_DIRECTORY_BASE_DN}\""
fi

#Keycloak integration
if ${DEPLOYMENT_KEYCLOAK_ENABLED}; then
  # Make URL to lowercase to avoid Keycloak matching conflicts
  DEP_URL="$(echo ${EXO_DEPLOYMENT_URL} | sed -e 's/\(.*\)/\L\1/')"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.saml.sp.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.callback.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.login.module.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.login.module.class=org.gatein.sso.agent.login.SAML2IntegrationLoginModule"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.valve.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.valve.class=org.gatein.sso.saml.plugin.valve.ServiceProviderAuthenticator"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.filter.login.sso.url=/portal/dologin"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.filter.initiatelogin.enabled=false"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.filter.logout.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.filter.logout.class=org.gatein.sso.saml.plugin.filter.SAML2LogoutFilter"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.sp.url=${DEP_URL}/portal/dologin"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.filter.logout.url=${DEP_URL}/portal/dologin?GLO=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.idp.host=$(echo ${DEP_URL} | sed -e 's|^[^/]*//||' -e 's|/.*$||')"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.idp.url=${DEP_URL}/auth/realms/master/protocol/saml"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.idp.alias=master"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.idp.signingkeypass=test123"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.idp.keystorepass=store123"
  CATALINA_OPTS="${CATALINA_OPTS} -Dgatein.sso.picketlink.keystore=${DEPLOYMENT_DIR}/gatein/conf/saml2/jbid_test_keystore.jks"
fi

#Jitsi integration
if ${DEPLOYMENT_JITSI_ENABLED}; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.jitsi.external.secret=MAPPudDBpSAqUwM0FY2r86gNAd6be5tN1xqwdFDOb4Us1DT4Tx"
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.jitsi.internal.secret=aMpulkJQhAAmUwM0FM4r16NgAd3fa5tNaxqqNFDdb49a4TPaFx"
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.jitsi.url=http://localhost:${DEPLOYMENT_JITSI_CALL_HTTP_PORT}"
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.webrtc.active=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.webrtc.default.stun.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.webrtc.exo.stun.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.webrtc.exo.turn.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.webrtc.exo.turn.username=acceptance"
  CATALINA_OPTS="${CATALINA_OPTS} -Dwebconferencing.webrtc.exo.turn.credential=acc3pt@nce" 
fi

#SFTP integration
if ${DEPLOYMENT_SFTP_ENABLED}; then
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.addons.lecko.job.enabled=true"
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.addons.lecko.out.name=acceptance_lecko"
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.addons.lecko.SftpHost=localhost"
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.addons.lecko.SftPortNumber=${DEPLOYMENT_SFTP_PORT}"
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.addons.lecko.SftpUser=root"
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.addons.lecko.SftpPassword=password"
  CATALINA_OPTS="${CATALINA_OPTS} -Dexo.addons.lecko.SftpRemotePath=/upload"
fi


#CMIS deployment on https is not supported
if ${DEPLOYMENT_CMISSERVER_ENABLED}; then
    CATALINA_OPTS="${CATALINA_OPTS} -Dclouddrive.service.schema=http"
    CATALINA_OPTS="${CATALINA_OPTS} -Dclouddrive.service.host=${DEPLOYMENT_CMIS_HOST}"
fi

# Skip register form
if ${DEPLOYMENT_SKIP_REGISTER}; then
    CATALINA_OPTS="${CATALINA_OPTS} -Dexo.registration.skip=true"
fi

# Push notification configuration
if ${DEPLOYMENT_PUSH_NOTIFICATIONS_ENABLED}; then
    [ ! -z "${DEPLOYMENT_PUSH_NOTIFICATIONS_CONFIGURATION_FILE}" ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.push.fcm.serviceAccountFilePath=${DEPLOYMENT_PUSH_NOTIFICATIONS_CONFIGURATION_FILE}"
fi

# Skip account creation form
CATALINA_OPTS="${CATALINA_OPTS} -Daccountsetup.skip=${EXO_SKIP_ACCOUNT_SETUP}"
CATALINA_OPTS="${CATALINA_OPTS} -Dexo.accountsetup.skip=${EXO_SKIP_ACCOUNT_SETUP}"
# PLF 4.1
# Email
[ ! -z ${EXO_DEPLOYMENT_URL} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.base.url=${EXO_DEPLOYMENT_URL}"
[ ! -z ${EXO_EMAIL_FROM} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.from=${EXO_EMAIL_FROM}"
[ ! -z ${EXO_EMAIL_SMTP_HOST} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.host=${EXO_EMAIL_SMTP_HOST}"
[ ! -z ${EXO_EMAIL_SMTP_PORT} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.port=${EXO_EMAIL_SMTP_PORT}"
[ ! -z ${EXO_EMAIL_SMTP_USERNAME} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.username=${EXO_EMAIL_SMTP_USERNAME}"
[ ! -z ${EXO_EMAIL_SMTP_PASSWORD} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.password=${EXO_EMAIL_SMTP_PASSWORD}"
[ ! -z ${EXO_EMAIL_SMTP_STARTTLS_ENABLE} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.starttls.enable=${EXO_EMAIL_SMTP_STARTTLS_ENABLE}"
[ ! -z ${EXO_EMAIL_SMTP_AUTH} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.auth=${EXO_EMAIL_SMTP_AUTH}"
[ ! -z ${EXO_EMAIL_SMTP_SOCKET_FACTORY_PORT} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.socketFactory.port=${EXO_EMAIL_SMTP_SOCKET_FACTORY_PORT}"
[ ! -z ${EXO_EMAIL_SMTP_SOCKET_FACTORY_CLASS} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.email.smtp.socketFactory.class=${EXO_EMAIL_SMTP_SOCKET_FACTORY_CLASS}"
# JOD
[ ! -z ${EXO_JODCONVERTER_ENABLE} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.jodconverter.enable=${EXO_JODCONVERTER_ENABLE}"
[ ! -z ${EXO_JODCONVERTER_PORTS} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.jodconverter.portnumbers=${EXO_JODCONVERTER_PORTS}"
[ ! -z ${EXO_JODCONVERTER_OFFICEHOME} ] && CATALINA_OPTS="${CATALINA_OPTS} -Dexo.jodconverter.officehome=\"${EXO_JODCONVERTER_OFFICEHOME}\""
# Debug Mode
if ${DEPLOYMENT_DEBUG_ENABLED:-false} ; then
  CATALINA_OPTS="${CATALINA_OPTS} -agentlib:jdwp=transport=dt_socket,address=${DEPLOYMENT_DEBUG_PORT},server=y,suspend=n"
fi
