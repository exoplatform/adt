import React from 'react';
import { useServers } from '../hooks/useServers';

const ServerCard = ({ host, data, meta, specs }) => {
  return (
    <div className={`server-card accent-${meta?.css || 'accX'}`}>
      <div className="server-card__header">
        <span className="server-card__name">{meta?.short || host}</span>
        <span className="server-card__badge">
          <i className="fas fa-server"></i> {data.nb} instances
        </span>
      </div>
      <div className="server-card__hostname">{host}</div>
      <div className="server-card__specs">
        <dt>CPU</dt><dd>{specs?.cpu || 'N/A'}</dd>
        <dt>RAM</dt><dd>{specs?.ram || 'N/A'}</dd>
        <dt>Storage</dt><dd>{specs?.disk || 'N/A'}</dd>
        <dt>JVM RAM</dt>
        <dd>
          <div className="jvm-range">
            <span className="jvm-min">{data['jvm-min'].toFixed(1)}GB</span>
            <i className="fas fa-arrows-alt-h text-muted small"></i>
            <span className="jvm-max">{data['jvm-max'].toFixed(1)}GB</span>
          </div>
        </dd>
      </div>
    </div>
  );
};

const ServersView = () => {
  const { data, isLoading, error } = useServers();

  if (isLoading) return <div className="text-center mt-5"><div className="spinner-border" role="status"></div><p>Loading servers...</p></div>;
  if (error) return <div className="alert alert-danger">Error loading servers: {error.message}</div>;

  return (
    <div>
      <h2 className="section-title"><i className="fas fa-server"></i> Server Infrastructure</h2>
      <div className="server-cards">
        {Object.entries(data.servers).map(([host, serverData]) => (
          <ServerCard 
            key={host} 
            host={host} 
            data={serverData} 
            meta={data.hostMeta[host]} 
            specs={data.serverSpecs[host]} 
          />
        ))}
      </div>

      <h2 className="section-title"><i className="fas fa-list"></i> Instances by Port</h2>
      <div className="table-responsive">
        <table className="table table-hover">
          <thead>
            <tr>
              <th>Port</th>
              <th>Host</th>
              <th>Instance</th>
              <th>Version</th>
            </tr>
          </thead>
          <tbody>
            {data.instances.map((instance) => (
              <tr key={instance.INSTANCE_KEY}>
                <td><span className="port-badge">{instance.DEPLOYMENT_HTTP_PORT}</span></td>
                <td>
                  <span className={`host-pill ${data.hostMeta[instance.ACCEPTANCE_HOST]?.css || 'accX'}`}>
                    {data.hostMeta[instance.ACCEPTANCE_HOST]?.short || instance.ACCEPTANCE_HOST}
                  </span>
                </td>
                <td>{instance.PRODUCT_DESCRIPTION || instance.PRODUCT_NAME}</td>
                <td>{instance.BASE_VERSION}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default ServersView;
