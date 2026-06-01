import React from 'react';
import { useInstances } from '../hooks/useInstances';
import InstanceTable from '../components/InstanceTable';

const HomeView = () => {
  const { data, isLoading, error } = useInstances('acceptance');

  if (isLoading) return <div className="text-center mt-5"><div className="spinner-border" role="status"></div><p>Loading instances...</p></div>;
  if (error) return <div className="alert alert-danger">Error loading instances: {error.message}</div>;

  return (
    <div className="row">
      <div className="col-12">
        <div className="alert alert-info">
          <i className="fas fa-flask me-2"></i>
          These instances are deployed to be used for acceptance tests.
        </div>
        <InstanceTable categories={data} />
      </div>
    </div>
  );
};

export default HomeView;
