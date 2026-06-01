import React, { createContext, useContext, useEffect, useState } from 'react';

const ThemeContext = createContext();

export const useTheme = () => useContext(ThemeContext);

export const ThemeProvider = ({ children }) => {
  const [accent, setAccent] = useState(() => {
    const raw = localStorage.getItem('theme');
    if (raw && raw.indexOf(':') > 0) return raw.split(':')[0];
    return 'default';
  });

  const [scheme, setScheme] = useState(() => {
    const raw = localStorage.getItem('theme');
    if (raw && raw.indexOf(':') > 0) return raw.split(':')[1];
    if (raw === 'light' || raw === 'dark') return raw;
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  });

  useEffect(() => {
    document.documentElement.setAttribute('data-accent', accent);
    document.documentElement.setAttribute('data-bs-theme', scheme);
    localStorage.setItem('theme', `${accent}:${scheme}`);
  }, [accent, scheme]);

  const toggleScheme = () => {
    setScheme(prev => (prev === 'dark' ? 'light' : 'dark'));
  };

  const changeAccent = (newAccent) => {
    setAccent(newAccent);
  };

  return (
    <ThemeContext.Provider value={{ accent, scheme, toggleScheme, changeAccent }}>
      {children}
    </ThemeContext.Provider>
  );
};
