import React, { useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';

export default function Register() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await axios.post('/api/register', { username, password });
      setMessage('Registration successful! Please login.');
      setError('');
      setTimeout(() => navigate('/login'), 1500);
    } catch (err) {
      setError('Registration failed. Username may already exist or password is too short.');
      setMessage('');
    }
  };

  return (
    <div className="form-container">
      <h2>Register</h2>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="Username"
          value={username}
          onChange={e => setUsername(e.target.value)}
          required
        /><br />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={e => setPassword(e.target.value)}
          required
        /><br />
        <button type="submit">Register</button>
      </form>
      {message && <div style={{color: 'green'}}>{message}</div>}
      {error && <div style={{color: 'red'}}>{error}</div>}
      <p>
        Already have an account? <a href="/login">Login</a>
      </p>
    </div>
  );
}