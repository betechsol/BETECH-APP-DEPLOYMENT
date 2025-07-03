import React, { useState } from 'react';
import { BrowserRouter as Router, Route, Routes, Navigate, useNavigate } from 'react-router';
import Login from './components/Login';
import Register from './components/Register';
import Home from './components/Home';

function App() {
  const [username, setUsername] = useState(localStorage.getItem('username') || '');

  const handleLogin = (user) => {
    setUsername(user);
    localStorage.setItem('username', user);
  };

  const handleLogout = () => {
    setUsername('');
    localStorage.removeItem('username');
  };

  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login onLogin={handleLogin} />} />
        <Route path="/register" element={<Register />} />
        <Route path="/home" element={username ? <Home username={username} onLogout={handleLogout} /> : <Navigate to="/login" />} />
        <Route path="/" element={<Navigate to={username ? "/home" : "/login"} />} />
      </Routes>
    </Router>
  );
}

export default App;