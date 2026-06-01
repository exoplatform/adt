import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useTheme } from '../context/ThemeContext';
import { Sun, Moon, Cloud, ChevronDown } from 'lucide-react';

const navItems = [
  { label: 'Home', path: '/' },
  { label: 'QA', path: '/qa' },
  { label: 'Sales', path: '/sales' },
  { label: 'CP', path: '/cp' },
  { label: 'Company', path: '/company' },
  { label: 'Features', path: '/features' },
  { label: 'Servers', path: '/servers' },
];

const themes = [
  { id: 'default', label: 'Default' },
  { id: 'ocean', label: 'Ocean' },
  { id: 'forest', label: 'Forest' },
  { id: 'twilight', label: 'Twilight' },
];

const Layout = ({ children }) => {
  const { accent, scheme, toggleScheme, changeAccent } = useTheme();
  const location = useLocation();

  return (
    <div id="wrap">
      <nav class="navbar navbar-expand-lg navbar-dark fixed-top">
        <div class="container-fluid">
          <Link class="navbar-brand" to="/">
            <Cloud className="me-2 d-inline-block align-text-top" size={24} />
            {window.location.hostname}
          </Link>
          <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
            <span class="navbar-toggler-icon"></span>
          </button>
          <div class="collapse navbar-collapse" id="navbarNav">
            <ul class="navbar-nav me-auto">
              {navItems.map((item) => (
                <li key={item.path} class="nav-item">
                  <Link
                    class={`nav-link ${location.pathname === item.path ? 'active' : ''}`}
                    to={item.path}
                    aria-current={location.pathname === item.path ? 'page' : undefined}
                  >
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
            <ul class="navbar-nav ms-auto align-items-center">
              <li class="nav-item dropdown">
                <button class="nav-link dropdown-toggle btn btn-link" id="themeDropdown" data-bs-toggle="dropdown">
                  {themes.find(t => t.id === accent)?.label || 'Default'}
                </button>
                <ul class="dropdown-menu dropdown-menu-end">
                  {themes.map((t) => (
                    <li key={t.id}>
                      <button class="dropdown-item" onClick={() => changeAccent(t.id)}>
                        {t.label}
                      </button>
                    </li>
                  ))}
                </ul>
              </li>
              <li class="nav-item">
                <button
                  class="nav-link btn btn-link"
                  onClick={toggleScheme}
                  title={scheme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
                >
                  {scheme === 'dark' ? <Sun size={20} /> : <Moon size={20} />}
                </button>
              </li>
            </ul>
          </div>
        </div>
      </nav>

      <main id="main" role="main">
        <div class="container-fluid">
          {children}
        </div>
      </main>

      <footer id="footer" class="footer">
        <div class="container-fluid">
          <div class="row">
            <div class="col">
              Copyright &copy; 2006-{new Date().getFullYear()}. All rights Reserved, eXo Platform SAS
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default Layout;
