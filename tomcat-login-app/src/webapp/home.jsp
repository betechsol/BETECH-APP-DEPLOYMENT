<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Home Page</title>
</head>
<body>
    <h1>Welcome to the Home Page!</h1>
    <%
        String username = (String) request.getSession().getAttribute("username");
        if (username != null) {
    %>
        <p>Hello, <%= username %>! You are logged in.</p>
        <a href="logout.jsp">Logout</a>
    <%
        } else {
    %>
        <p>You are not logged in. Please <a href="login.jsp">login</a>.</p>
    <%
        }
    %>
</body>
</html>