# Tomcat Login Application

This project is a simple web application built using Java Servlets and JSP that allows users to register and log in. It uses PostgreSQL as the database to store user information.

## Project Structure

```
tomcat-login-app
├── src
│   ├── main
│   │   ├── java
│   │   │   └── com
│   │   │       └── example
│   │   │           ├── servlet
│   │   │           │   ├── LoginServlet.java
│   │   │           │   └── RegisterServlet.java
│   │   │           └── dao
│   │   │               └── UserDao.java
│   │   └── resources
│   │       └── db.properties
│   └── webapp
│       ├── WEB-INF
│       │   └── web.xml
│       ├── login.jsp
│       ├── register.jsp
│       └── home.jsp
├── pom.xml
└── README.md
```

## Features

- User Registration: New users can create an account by providing their username and password.
- User Login: Registered users can log in using their credentials.
- PostgreSQL Database: User information is securely stored in a PostgreSQL database.

## Setup Instructions

1. **Clone the Repository**
   ```
   git clone <repository-url>
   cd tomcat-login-app
   ```

2. **Configure Database**
   - Update the `src/main/resources/db.properties` file with your PostgreSQL database connection details.

3. **Build the Project**
   - Use Maven to build the project:
   ```
   mvn clean install
   ```

4. **Deploy to Tomcat**
   - Deploy the generated WAR file located in the `target` directory to your Tomcat server.

5. **Access the Application**
   - Open your web browser and navigate to `http://localhost:8080/tomcat-login-app`.

## Usage

- **Register**: Navigate to the registration page to create a new account.
- **Login**: Use the login page to access your account.
- **Home Page**: After logging in, you will be redirected to the home page where you can see a welcome message.

## Dependencies

- Java Servlet API
- JSP API
- PostgreSQL JDBC Driver

## License

This project is licensed under the MIT License. See the LICENSE file for more details.