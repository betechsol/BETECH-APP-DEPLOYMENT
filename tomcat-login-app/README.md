# Tomcat Login Application

This project is a simple web application built with Java Servlets and JSP that allows users to register and log in. User credentials are stored securely in a PostgreSQL database.

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

- **User Registration:** New users can create an account with a username and password.
- **User Login:** Registered users can log in with their credentials.
- **Session Management:** Users remain logged in until they log out or the session expires.
- **PostgreSQL Integration:** User data is stored in a PostgreSQL database.
- **Simple UI:** JSP pages for login, registration, and home.

## Setup Instructions

1. **Clone the Repository**
   ```sh
   git clone <repository-url>
   cd tomcat-login-app
   ```

2. **Configure the Database**
   - Create a PostgreSQL database and user.
   - Update `src/main/resources/db.properties` with your database connection details:
     ```
     db.url=jdbc:postgresql://localhost:5432/<your-db>
     db.username=<your-username>
     db.password=<your-password>
     ```

   - Example SQL to create the users table:
     ```sql
     CREATE TABLE users (
       id SERIAL PRIMARY KEY,
       username VARCHAR(50) UNIQUE NOT NULL,
       password VARCHAR(255) NOT NULL
     );
     ```

3. **Build the Project**
   ```sh
   mvn clean install
   ```

4. **Deploy to Tomcat**
   - Copy the generated WAR file from the `target` directory to your Tomcat `webapps` folder.

5. **Access the Application**
   - Open your browser and go to: [http://localhost:8080/tomcat-login-app](http://localhost:8080/tomcat-login-app)

## Usage

- **Register:** Go to `/register.jsp` to create a new account.
- **Login:** Go to `/login.jsp` to log in.
- **Home:** After logging in, you will be redirected to `/home.jsp`.

## Dependencies

- Java Servlet API
- JSP API
- PostgreSQL JDBC Driver

## License

This project is licensed under the MIT License. See the LICENSE file for details.