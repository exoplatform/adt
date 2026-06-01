import React from 'react';
import { Circle, Info, Database, Download } from 'lucide-react';

export const StatusIcon = ({ status }) => (
  <i 
    className={`fas fa-circle text-${status === 'Up' ? 'success' : 'danger'}`} 
    title={`Status: ${status}`}
  ></i>
);

export const AppServerIcon = ({ type }) => {
  const icons = {
    tomcat: 'fa-java',
    jboss: 'fa-redhat',
    wildfly: 'fa-redhat'
  };
  const icon = icons[type.toLowerCase()] || 'fa-server';
  return <i className={`fab ${icon}`} title={`Application Server: ${type}`}></i>;
};

export const DatabaseIcon = ({ database, version }) => {
  let color = 'text-secondary';
  const db = database.toLowerCase();
  if (db.includes('mysql')) color = 'text-primary';
  else if (db.includes('mariadb')) color = 'text-success';
  else if (db.includes('postgres')) color = 'text-info';
  else if (db.includes('oracle')) color = 'text-danger';
  else if (db.includes('sqlserver')) color = 'text-warning';

  return (
    <span className="d-inline-flex align-items-center gap-1">
      <i className={`fas fa-database ${color}`} title={database}></i>
      <span className="badge bg-info">{version || '-NC-'}</span>
    </span>
  );
};

export const VisibilityIcon = ({ security }) => {
  const icons = {
    public: 'fa-globe',
    private: 'fa-lock'
  };
  const icon = icons[security] || 'fa-question-circle';
  const color = security === 'public' ? 'text-success' : '';
  return <i className={`fas ${icon} ${color}`} title={`Visibility: ${security}`}></i>;
};

export const DownloadIcon = ({ artifact }) => (
  <a href={artifact.ARTIFACT_DL_URL} title="Download Artifact">
    <i className="fas fa-download"></i>
  </a>
);

export const ActionButtons = ({ instance }) => {
  const deploymentURL = instance.DEPLOYMENT_APACHE_VHOST_ALIAS || instance.DEPLOYMENT_EXT_HOST;
  
  return (
    <div className="btn-group btn-group-sm">
      <a href={instance.DEPLOYMENT_LOG_APPSRV_URL} className="btn btn-outline-secondary" title="Instance logs" target="_blank">
        <i className="fas fa-file-alt"></i>
      </a>
      <a href={instance.DEPLOYMENT_LOG_APACHE_URL} className="btn btn-outline-secondary" title="Apache logs" target="_blank">
        <i className="fas fa-server"></i>
      </a>
      {instance.DEPLOYMENT_JMX_URL && (
        <a href={instance.DEPLOYMENT_JMX_URL} className="btn btn-outline-secondary" title="JMX monitoring" target="_blank">
          <i className="fas fa-chart-line"></i>
        </a>
      )}
      {instance.DEPLOYMENT_LDAP_LINK && (
        <a href={instance.DEPLOYMENT_LDAP_LINK} className="btn btn-outline-secondary" title="LDAP url" target="_blank">
          <i className="fas fa-address-book"></i>
        </a>
      )}
      <a href={instance.DEPLOYMENT_AWSTATS_URL} className="btn btn-outline-secondary" title="Usage statistics" target="_blank">
        <i className="fas fa-chart-bar"></i>
      </a>
      {instance.DEPLOYMENT_ES_ENABLED && (
        <a href={`http://${deploymentURL}/elasticsearch`} className="btn btn-outline-secondary" title="Elasticsearch" target="_blank">
          <i className="fas fa-search"></i>
        </a>
      )}
      {instance.DEPLOYMENT_MAILPIT_ENABLED && (
        <a href={`http://${deploymentURL}/mailpit/`} className="btn btn-outline-secondary" title="Mailpit" target="_blank">
          <i className="fas fa-envelope"></i>
        </a>
      )}
      {instance.DEPLOYMENT_MONGO_EXPRESS_ENABLED && (
        <a href={`http://${deploymentURL}/mongoexpress/`} className="btn btn-outline-secondary" title="Mongo Express" target="_blank">
          <i className="fas fa-database"></i>
        </a>
      )}
      {instance.DEPLOYMENT_KEYCLOAK_ENABLED && (
        <a href={`http://${deploymentURL}/auth/admin/`} className="btn btn-outline-secondary" title="Keycloak" target="_blank">
          <i className="fas fa-key"></i>
        </a>
      )}
      {instance.DEPLOYMENT_CLOUDBEAVER_ENABLED && (
        <a href={`http://${deploymentURL}/cloudbeaver/`} className="btn btn-outline-secondary" title="CloudBeaver" target="_blank">
          <i className="fas fa-cloud"></i>
        </a>
      )}
      {instance.DEPLOYMENT_PHPLDAPADMIN_ENABLED && (
        <a href={`http://${deploymentURL}:${instance.DEPLOYMENT_PHPLDAPADMIN_HTTP_PORT}`} className="btn btn-outline-secondary" title="phpLDAPAdmin" target="_blank">
          <i className="fas fa-address-book"></i>
        </a>
      )}
      {instance.DEPLOYMENT_SFTP_ENABLED && (
        <a href={instance.DEPLOYMENT_SFTP_LINK} className="btn btn-outline-secondary" title="SFTP" target="_blank">
          <i className="fas fa-file-export"></i>
        </a>
      )}
      {instance.DEPLOYMENT_FRONTAIL_ENABLED && (
        <a href={`http://${deploymentURL}/livelogs/`} className="btn btn-outline-secondary" title="Instance Live logs" target="_blank">
          <i className="fas fa-play-circle"></i>
        </a>
      )}
    </div>
  );
};
