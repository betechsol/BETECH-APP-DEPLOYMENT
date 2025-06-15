package com.example.dao;

import com.example.model.User;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class UserDao {
    private String jdbcURL;
    private String jdbcUsername;
    private String jdbcPassword;
    private Connection jdbcConnection;

    public UserDao(String jdbcURL, String jdbcUsername, String jdbcPassword) {
        this.jdbcURL = jdbcURL;
        this.jdbcUsername = jdbcUsername;
        this.jdbcPassword = jdbcPassword;
    }

    protected void connect() throws SQLException {
        if (jdbcConnection == null || jdbcConnection.isClosed()) {
            jdbcConnection = DriverManager.getConnection(jdbcURL, jdbcUsername, jdbcPassword);
        }
    }

    protected void disconnect() throws SQLException {
        if (jdbcConnection != null && !jdbcConnection.isClosed()) {
            jdbcConnection.close();
        }
    }

    public User getUserByUsername(String username) throws SQLException {
        User user = null;
        String sql = "SELECT * FROM users WHERE username = ?";
        connect();

        PreparedStatement statement = jdbcConnection.prepareStatement(sql);
        statement.setString(1, username);

        ResultSet resultSet = statement.executeQuery();

        if (resultSet.next()) {
            String password = resultSet.getString("password");
            user = new User(username, password);
        }

        resultSet.close();
        statement.close();
        disconnect();
        return user;
    }

    public void saveUser(User user) throws SQLException {
        String username = user.getUsername();
        String password = user.getPassword();

        if (getUserByUsername(username) != null) {
            throw new SQLException("User already exists");
        }
        if (username == null || username.isEmpty() || password == null || password.isEmpty()) {
            throw new SQLException("Username and password cannot be empty");
        }
        if (username.length() < 3 || password.length() < 6) {
            throw new SQLException("Username must be at least 3 characters and password at least 6 characters long");
        }

        String sql = "INSERT INTO users (username, password) VALUES (?, ?)";
        connect();

        PreparedStatement statement = jdbcConnection.prepareStatement(sql);
        statement.setString(1, username);
        statement.setString(2, password);

        statement.executeUpdate();
        statement.close();
        disconnect();
    }
}