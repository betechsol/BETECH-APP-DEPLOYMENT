package com.betech.controller;

import com.betech.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
// @CrossOrigin(origins = {"http://localhost:3000", "http://hostPublicIP:3000"})
@CrossOrigin(origins = {"http://localhost:3000", "*"})
@RequestMapping("/api")
public class AuthController {
    @Autowired
    private UserService userService;

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, String> payload) {
        String username = payload.get("username");
        String password = payload.get("password");
        try {
            userService.register(username, password);
            return ResponseEntity.ok("Registration successful");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestParam String username, @RequestParam String password) {
        try {
            userService.login(username, password);
            return ResponseEntity.ok("Login successful");
        } catch (Exception e) {
            return ResponseEntity.status(401).body("Invalid credentials");
        }
    }
}