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
[ -z $EXO_JVM_PERMSIZE_MIN ] && EXO_JVM_PERMSIZE_MIN="${DEPLOYMENT_JVM_PERMSIZE_MIN}"
# JMX
[ -z $EXO_JVM_JMX_REMOTE_HOSTNAME ] && EXO_JVM_JMX_REMOTE_HOSTNAME="${DEPLOYMENT_EXT_HOST}"
# Email
# Domain name: Help for sending links from email notifications. The default domain name is http://localhost:8080.
[ -z $EXO_DEPLOYMENT_URL ] && EXO_DEPLOYMENT_URL="${DEPLOYMENT_EXT_HOST}"
# Email display in "from" field of email notification.
[ -z $EXO_EMAIL_FROM ] && EXO_EMAIL_FROM="noreply@exoplatform.com"
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
# LDAP
[ -z $EXO_LDAP_URL ] && EXO_LDAP_URL="${DEPLOYMENT_LDAP_URL}"
[ -z $EXO_LDAP_ADMIN_DN ] && EXO_LDAP_ADMIN_DN="${DEPLOYMENT_LDAP_ADMIN_DN}"
[ -z $EXO_LDAP_ADMIN_PWD ] && EXO_LDAP_ADMIN_PWD="${DEPLOYMENT_LDAP_ADMIN_PWD}"
[ -z $EXO_LDAP_READ_ONLY ] && EXO_LDAP_READ_ONLY="true"
# Datasources
EXO_DS_IDM_DRIVER="com.mysql.jdbc.Driver"
EXO_DS_IDM_USERNAME="${DEPLOYMENT_DATABASE_USER}"
EXO_DS_IDM_PASSWORD="${DEPLOYMENT_DATABASE_USER}"
EXO_DS_IDM_URL="jdbc:mysql://localhost:3306/${DEPLOYMENT_DATABASE_NAME}?autoReconnect=true"
EXO_DS_PORTAL_DRIVER="com.mysql.jdbc.Driver"
EXO_DS_PORTAL_USERNAME="${DEPLOYMENT_DATABASE_USER}"
EXO_DS_PORTAL_PASSWORD="${DEPLOYMENT_DATABASE_USER}"
EXO_DS_PORTAL_URL="jdbc:mysql://localhost:3306/${DEPLOYMENT_DATABASE_NAME}?autoReconnect=true"
# PORTS
EXO_TOMCAT_SHUTDOWN_PORT=${DEPLOYMENT_SHUTDOWN_PORT}
EXO_TOMCAT_RMI_REGISTRY_PORT=${DEPLOYMENT_RMI_REG_PORT}
EXO_TOMCAT_RMI_SERVER_PORT=${DEPLOYMENT_RMI_SRV_PORT}
EXO_HTTP_PORT=${DEPLOYMENT_HTTP_PORT}
EXO_AJP_PORT=${DEPLOYMENT_AJP_PORT}
# JVM
CATALINA_OPTS="${CATALINA_OPTS} -XX:+HeapDumpOnOutOfMemoryError"
CATALINA_OPTS="${CATALINA_OPTS} -XX:HeapDumpPath=${CATALINA_HOME}/logs/"
# CRaSH
CATALINA_OPTS="${CATALINA_OPTS} -Dcrash.telnet.port=${EXO_CRASH_TELNET_PORT}"
CATALINA_OPTS="${CATALINA_OPTS} -Dcrash.ssh.port=${EXO_CRASH_SSH_PORT}"
