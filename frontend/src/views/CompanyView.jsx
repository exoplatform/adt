import React from 'react';
import { useInstances } from '../hooks/useInstances';
import InstanceTable from '../components/InstanceTable';

const CompanyView = () => {
  const { data, isLoading, error } = useInstances('company');

  if (isLoading) return <div className="text-center mt-5"><div className="spinner-border" role="status"></div><p>Loading company projects...</p></div>;
  if (error) return <div className="alert alert-danger">Error loading company projects: {error.message}</div>;

  return (
    <div className="row">
      <div className="col-12">
        <div className="alert alert-info">
          <i className="fas fa-building me-2"></i>
          Company environments and deployments
        </div>

        <ul className="list-unstyled company-links-list p-3 rounded mb-4">
          <li className="mb-2">
            <i className="fas fa-globe text-primary me-2"></i>eXo Website :
            <a href="https://www-dev.exoplatform.com/" target="_blank" rel="noreferrer" className="badge bg-info text-decoration-none ms-2">(development) www-dev.exoplatform.com</a>
            <span className="mx-1">-</span>
            <a href="https://www-preprod.exoplatform.com/" target="_blank" rel="noreferrer" className="badge bg-warning text-decoration-none">(pre-production) www-preprod.exoplatform.com</a>
          </li>
          <li className="mb-2">
            <i className="fas fa-users text-primary me-2"></i>eXo Tribe :
            <a href="https://community-dev.exoplatform.com/" target="_blank" rel="noreferrer" className="badge bg-info text-decoration-none ms-2">(development) community-dev.exoplatform.com</a>
            <span className="mx-1">-</span>
            <a href="https://community-preprod.exoplatform.com/" target="_blank" rel="noreferrer" className="badge bg-warning text-decoration-none">(pre-production) community-preprod.exoplatform.com</a>
          </li>
          <li className="mb-2">
            <i className="fas fa-blog text-primary me-2"></i>eXo Blog :
            <a href="https://blog-dev.exoplatform.com/" target="_blank" rel="noreferrer" className="badge bg-info text-decoration-none ms-2">(development) blog-dev.exoplatform.com/</a>
            <span className="mx-1">-</span>
            <a href="https://blog-preprod.exoplatform.com/blog/" target="_blank" rel="noreferrer" className="badge bg-warning text-decoration-none">(pre-production) www-preprod.exoplatform.com/blog/</a>
          </li>
        </ul>

        <InstanceTable categories={data} />
      </div>
    </div>
  );
};

export default CompanyView;
