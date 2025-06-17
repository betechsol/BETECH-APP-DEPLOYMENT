import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
// import logo from './logo.svg';
import './App.css';
import Home from './components/Home';
import Login from './components/Login';
import Register from './components/Register';

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
      <div className="App">
        {/* <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
          <p>
            Edit <code>src/App.js</code> and save to reload.
          </p>
          <a
            className="App-link"
            href="https://reactjs.org"
            target="_blank"
            rel="noopener noreferrer"
          >
            Learn React
          </a>
        </header> */}
        <Routes>
          <Route path="/login" element={<Login onLogin={handleLogin} />} />
          <Route path="/register" element={<Register />} />
          <Route
            path="/home"
            element={
              username ? (
                <Home username={username} onLogout={handleLogout} />
              ) : (
                <Navigate to="/login" />
              )
            }
          />
          <Route
            path="/"
            element={<Navigate to={username ? "/home" : "/login"} />}
          />
        </Routes>
      </div>
    </Router>
  );
}

export default App;
