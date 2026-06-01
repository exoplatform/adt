import React from 'react';
import { StatusIcon, AppServerIcon, DatabaseIcon, VisibilityIcon, DownloadIcon, ActionButtons } from './InstanceIcons';

const InstanceRow = ({ instance }) => {
  const url = instance.DEPLOYMENT_APACHE_VHOST_ALIAS 
    ? `http://${instance.DEPLOYMENT_APACHE_VHOST_ALIAS}` 
    : instance.DEPLOYMENT_URL;

  return (
    <tr>
      <td className="col-center"><StatusIcon status={instance.DEPLOYMENT_STATUS} /></td>
      <td>
        <div className="d-flex align-items-center">
          <i className="fas fa-info-circle text-info me-2"></i>
          <div className="ms-2">
            <VisibilityIcon security={instance.DEPLOYMENT_APACHE_SECURITY} />
            <AppServerIcon type={instance.DEPLOYMENT_APPSRV_TYPE} />
            <a href={url} target="_blank" rel="noopener noreferrer" className="ms-2">
              {instance.PRODUCT_DESCRIPTION || instance.PRODUCT_NAME}
              {instance.INSTANCE_ID && ` (${instance.INSTANCE_ID})`}
            </a>
          </div>
        </div>
      </td>
      <td>
        <DownloadIcon artifact={instance} />
        <span className="ms-2">{instance.BASE_VERSION}</span>
      </td>
      <td className="col-center">
        <DatabaseIcon database={instance.DATABASE} version={instance.DEPLOYMENT_DATABASE_VERSION} />
      </td>
      <td className="col-center" colSpan="4"></td>
      <td className={`col-right ${instance.ARTIFACT_AGE_CLASS}`}>
        <i className="fas fa-calendar-alt me-1"></i>{instance.ARTIFACT_AGE_STRING}
      </td>
      <td className="col-right">
        <i className="fas fa-clock me-1"></i>{instance.DEPLOYMENT_AGE_STRING}
      </td>
      <td className="col-left">
        <ActionButtons instance={instance} />
      </td>
    </tr>
  );
};

const InstanceTable = ({ categories }) => {
  if (!categories || Object.keys(categories).length === 0) {
    return <div className="alert alert-warning">No instances found.</div>;
  }

  return (
    <div className="table-responsive">
      <table className="table table-hover">
        <thead>
          <tr>
            <th className="col-center">S</th>
            <th className="col-center">Name</th>
            <th className="col-center">Version</th>
            <th className="col-center">Database</th>
            <th className="col-center" colSpan="4">Feature Branch</th>
            <th className="col-center">Built</th>
            <th className="col-center">Deployed</th>
            <th className="col-center">Actions</th>
          </tr>
        </thead>
        <tbody>
          {Object.entries(categories).map(([category, instances]) => (
            <React.Fragment key={category}>
              <tr>
                <td colSpan="15" className="category-row">
                  <i className="fas fa-tag me-2"></i>{category}
                </td>
              </tr>
              {instances.map((instance) => (
                <InstanceRow key={instance.INSTANCE_KEY} instance={instance} />
              ))}
            </React.Fragment>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default InstanceTable;
