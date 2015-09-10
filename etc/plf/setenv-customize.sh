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
if ${DEPLOYMENT_ES_EMBEDDED_ENABLED}; then
    CATALINA_OPTS="${CATALINA_OPTS} -Des.http.port=${EXO_ES_EMBEDDED_HTTP_PORT}"
    CATALINA_OPTS="${CATALINA_OPTS} -Des.path.data=${CATALINA_HOME}/${DEPLOYMENT_ES_EMBEDDED_PATH_DATA}"
fi
# eXo Addon Chat
if ${DEPLOYMENT_CHAT_ENABLED}; then
    CATALINA_OPTS="${CATALINA_OPTS} -Dchat.weemoKey=${EXO_CHAT_WEEMO_KEY}"
    CATALINA_OPTS="${CATALINA_OPTS} -Dchat.dbName=${EXO_CHAT_MONGODB_NAME}"
    CATALINA_OPTS="${CATALINA_OPTS} -Dchat.dbServerHost=${EXO_CHAT_MONGODB_HOSTNAME}"
    CATALINA_OPTS="${CATALINA_OPTS} -Dchat.dbServerPort=${EXO_CHAT_MONGODB_PORT}"
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
