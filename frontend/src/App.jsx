import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from './context/ThemeContext';
import Layout from './components/Layout';
import HomeView from './views/HomeView';
import InstancesView from './views/InstancesView';
import FeaturesView from './views/FeaturesView';
import ServersView from './views/ServersView';
import CompanyView from './views/CompanyView';
import { useWebSockets } from './hooks/useWebSockets';

const queryClient = new QueryClient();

const AppContent = () => {
  useWebSockets();

  return (
    <Layout>
      <Routes>
        <Route path="/" element={<HomeView />} />
        <Route path="/qa" element={
          <InstancesView 
            type="qa" 
            title="QA Environments" 
            infoMessage="These instances are deployed for eXo QA Team members usage only." 
          />
        } />
        <Route path="/sales" element={
          <InstancesView 
            type="sales" 
            title="Sales & Demo" 
            infoMessage="These instances are used for sales demos and evaluations." 
          />
        } />
        <Route path="/cp" element={
          <InstancesView 
            type="cp" 
            title="CP Instances" 
            infoMessage="Customer instances for project acceptance." 
          />
        } />
        <Route path="/company" element={<CompanyView />} />
        <Route path="/features" element={<FeaturesView />} />
        <Route path="/servers" element={<ServersView />} />
      </Routes>
    </Layout>
  );
};

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <Router>
          <AppContent />
        </Router>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;
