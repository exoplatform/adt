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
# Acceptance Settings customizations
# -----------------------------------------------------------------------------
CATALINA_HOME="${DEPLOYMENT_DIR}"
CATALINA_PID="${DEPLOYMENT_PID_FILE}"
# Logs
export EXO_LOGS_DISPLAY_CONSOLE=true
export EXO_LOGS_COLORIZED_CONSOLE=true
# JVM configuration
[ -z $EXO_JVM_SIZE_MAX ] && EXO_JVM_SIZE_MAX="${DEPLOYMENT_JVM_SIZE_MAX}"
[ -z $EXO_JVM_SIZE_MIN ] && EXO_JVM_SIZE_MIN="${DEPLOYMENT_JVM_SIZE_MIN}"
[ -z $EXO_JVM_PERMSIZE_MAX ] && EXO_JVM_PERMSIZE_MAX="${DEPLOYMENT_JVM_PERMSIZE_MAX}"
# JMX
[ -z $EXO_JVM_JMX_REMOTE_HOSTNAME ] && EXO_JVM_JMX_REMOTE_HOSTNAME="${DEPLOYMENT_EXT_HOST}"
# Email
# Domain name: Help for sending links from email notifications. The default domain name is http://localhost:8080.
[ -z $EXO_DEPLOYMENT_URL ] && EXO_DEPLOYMENT_URL="${DEPLOYMENT_URL}"
# Email display in "from" field of email notification.
[ -z $EXO_EMAIL_FROM ] && EXO_EMAIL_FROM="noreply+acceptance@exoplatform.com"
[ -z $EXO_EMAIL_SMTP_USERNAME ] && EXO_EMAIL_SMTP_USERNAME=""
[ -z $EXO_EMAIL_SMTP_PASSWORD ] && EXO_EMAIL_SMTP_PASSWORD=""
[ -z $EXO_EMAIL_SMTP_HOST ] && EXO_EMAIL_SMTP_HOST="localhost"
[ -z $EXO_EMAIL_SMTP_PORT ] && EXO_EMAIL_SMTP_PORT="25"
[ -z $EXO_EMAIL_SMTP_STARTTLS_ENABLE ] && EXO_EMAIL_SMTP_STARTTLS_ENABLE="false"
[ -z $EXO_EMAIL_SMTP_AUTH ] && EXO_EMAIL_SMTP_AUTH="false"
[ -z $EXO_EMAIL_SMTP_SOCKET_FACTORY_PORT ] && EXO_EMAIL_SMTP_SOCKET_FACTORY_PORT=""
[ -z $EXO_EMAIL_SMTP_SOCKET_FACTORY_CLASS ] && EXO_EMAIL_SMTP_SOCKET_FACTORY_CLASS=""
# JOD Server
[ -z $EXO_JODCONVERTER_PORTS ] && EXO_JODCONVERTER_PORTS="${DEPLOYMENT_JOD_CONVERTER_PORTS}"
# CRaSH
[ -z $EXO_CRASH_TELNET_PORT ] && EXO_CRASH_TELNET_PORT="${DEPLOYMENT_CRASH_TELNET_PORT}"
[ -z $EXO_CRASH_SSH_PORT ] && EXO_CRASH_SSH_PORT="${DEPLOYMENT_CRASH_SSH_PORT}"
# eXo Addon Chat
[ -z $EXO_CHAT_WEEMO_KEY ] && EXO_CHAT_WEEMO_KEY="${DEPLOYMENT_CHAT_WEEMO_KEY}"
[ -z $EXO_CHAT_MONGODB_NAME ] && EXO_CHAT_MONGODB_NAME="${DEPLOYMENT_CHAT_MONGODB_NAME}"
[ -z $EXO_CHAT_MONGODB_HOSTNAME ] && EXO_CHAT_MONGODB_HOSTNAME="${DEPLOYMENT_CHAT_MONGODB_HOSTNAME}"
[ -z $EXO_CHAT_MONGODB_PORT ] && EXO_CHAT_MONGODB_PORT="${DEPLOYMENT_CHAT_MONGODB_PORT}"
# Skip account creation form
[ -z $EXO_SKIP_ACCOUNT_SETUP ] && EXO_SKIP_ACCOUNT_SETUP="${DEPLOYMENT_SKIP_ACCOUNT_SETUP}"
# Elasticsearch Embedded
[ -z $EXO_ES_HTTP_PORT ] && EXO_ES_HTTP_PORT="${DEPLOYMENT_ES_HTTP_PORT}"
[ -z $EXO_ES_PATH_DATA ] && EXO_ES_PATH_DATA="${DEPLOYMENT_ES_PATH_DATA}"
