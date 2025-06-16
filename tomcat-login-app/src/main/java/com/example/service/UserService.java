package com.example.service;

import com.example.model.User;
import com.example.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class UserService {
    @Autowired
    private UserRepository userRepository;

    public User register(String username, String password) throws Exception {
        if (userRepository.findByUsername(username) != null) {
            throw new Exception("User already exists");
        }
        if (username == null || username.isEmpty() || password == null || password.isEmpty()) {
            throw new Exception("Username and password cannot be empty");
        }
        if (username.length() < 3 || password.length() < 6) {
            throw new Exception("Username must be at least 3 characters and password at least 6 characters long");
        }
        User user = new User();
        user.setUsername(username);
        user.setPassword(password);
        return userRepository.save(user);
    }

    public User login(String username, String password) throws Exception {
        User user = userRepository.findByUsername(username);
        if (user == null || !user.getPassword().equals(password)) {
            throw new Exception("Invalid credentials");
        }
        return user;
    }
}