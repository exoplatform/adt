import React from 'react';
import { useInstances } from '../hooks/useInstances';
import InstanceTable from '../components/InstanceTable';

const InstancesView = ({ type, title, infoMessage }) => {
  const { data, isLoading, error } = useInstances(type);

  if (isLoading) return <div className="text-center mt-5"><div className="spinner-border" role="status"></div><p>Loading {title}...</p></div>;
  if (error) return <div className="alert alert-danger">Error loading {title}: {error.message}</div>;

  // For sales, data is nested
  const categories = type === 'sales' ? { ...data.user, ...data.demo, ...data.eval } : data;

  return (
    <div className="row">
      <div className="col-12">
        {infoMessage && (
          <div className="alert alert-info">
            <i className="fas fa-info-circle me-2"></i>
            {infoMessage}
          </div>
        )}
        <h1>{title}</h1>
        <InstanceTable categories={categories} />
      </div>
    </div>
  );
};

export default InstancesView;
