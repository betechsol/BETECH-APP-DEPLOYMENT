package com.example.servlet;

import com.example.dao.UserDao;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

@WebServlet("/register")
public class RegisterServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;
    private UserDao userDao;

    public void init() {
        userDao = new UserDao();
    }

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String username = request.getParameter("username");
        String password = request.getParameter("password");
        String email = request.getParameter("email");

        if (username != null && password != null && email != null) {
            userDao.saveUser(username, password, email);
            response.sendRedirect("login.jsp");
        } else {
            request.setAttribute("errorMessage", "All fields are required.");
            request.getRequestDispatcher("register.jsp").forward(request, response);
        }
    }
}