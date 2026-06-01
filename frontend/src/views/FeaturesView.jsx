import React from 'react';
import { useFeatures } from '../hooks/useFeatures';

const FeatureCard = ({ name, projects }) => {
  return (
    <div className="feature-card card mb-3" id={`feature-${name.replace(/[/.]/g, '-')}`}>
      <div className="card-body">
        <div className="feature-title">
          <i className="fas fa-bookmark text-warning"></i>
          <h5 className="feature-branch-link"><code>{name}</code></h5>
          <div className="feature-actions ms-auto">
            <a href={`https://ci.exoplatform.org/job/exo-${name}-fb-rebase-branch/`} target="_blank" className="btn btn-sm btn-outline-primary">
              <i className="fas fa-sync-alt"></i> Rebase
            </a>
          </div>
        </div>
        <div className="project-grid">
          {Object.entries(projects).map(([projectName, projectData]) => (
            <div key={projectName} className="project-chip">
              <div className="project-chip-header">{projectName}</div>
              <div className="commit-stats">
                <span className={`commit-stat ${projectData.behind_commits > 0 ? 'behind' : ''}`}>
                  <i className="fas fa-arrow-down"></i> {projectData.behind_commits}
                </span>
                <span className={`commit-stat ${projectData.ahead_commits > 0 ? 'ahead' : ''}`}>
                  <i className="fas fa-arrow-up"></i> {projectData.ahead_commits}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const FeaturesView = () => {
  const { data, isLoading, error } = useFeatures();

  if (isLoading) return <div className="text-center mt-5"><div className="spinner-border" role="status"></div><p>Loading features...</p></div>;
  if (error) return <div className="alert alert-danger">Error loading features: {error.message}</div>;

  return (
    <div>
      <div className="alert alert-info d-flex align-items-center">
        <i className="fas fa-code-branch fa-2x me-3"></i>
        <div>
          <h5 className="alert-heading mb-1">Feature Branches Overview</h5>
          <p className="mb-0">This page summarizes all Git feature branches and their health.</p>
        </div>
      </div>

      <div className="card mb-4">
        <div className="card-header d-flex align-items-center">
          <i className="fas fa-check-circle text-success me-2"></i>
          <h5 className="mb-0">Feature Branches deployed on acceptance</h5>
          <span className="badge bg-success ms-2">{Object.keys(data.acceptedFeatures).length}</span>
        </div>
        <div className="card-body">
          {Object.entries(data.acceptedFeatures).map(([name, projects]) => (
            <FeatureCard key={name} name={name} projects={projects} />
          ))}
        </div>
      </div>

      <div className="card mb-4">
        <div className="card-header d-flex align-items-center">
          <i className="fas fa-clock text-warning me-2"></i>
          <h5 className="mb-0">Other Feature Branches</h5>
          <span className="badge bg-warning ms-2">{Object.keys(data.otherFeatures).length}</span>
        </div>
        <div className="card-body">
          {Object.entries(data.otherFeatures).map(([name, projects]) => (
            <FeatureCard key={name} name={name} projects={projects} />
          ))}
        </div>
      </div>
    </div>
  );
};

export default FeaturesView;
