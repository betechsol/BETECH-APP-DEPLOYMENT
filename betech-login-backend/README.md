# Spring Boot Login Application

This project is a simple web application built with Spring Boot, Spring Data JPA, and Thymeleaf. It allows users to register and log in. User credentials are securely stored in a PostgreSQL database.

## Project Structure

```
betech-login-backend
├── src
│   ├── main
│   │   ├── java
│   │   │   └── com
│   │   │       └── example
│   │   │           ├── BetechLoginBackendApplication.java
│   │   │           ├── controller
│   │   │           │   └── AuthController.java
│   │   │           ├── model
│   │   │           │   └── User.java
│   │   │           ├── repository
│   │   │           │   └── UserRepository.java
│   │   │           └── service
│   │   │               └── UserService.java
│   │   └── resources
│   │       ├── application.properties
│   │       └── templates
│   │           ├── login.html
│   │           ├── register.html
│   │           └── home.html
│   └── test
│       └── java
│           └── com
│               └── example
│                   └── BetechLoginBackendApplicationTests.java
├── pom.xml
└── README.md
```

## Features

- **User Registration:** New users can create an account with a username and password.
- **User Login:** Registered users can log in with their credentials.
- **Session Management:** Users remain logged in until they log out or the session expires.
- **PostgreSQL Integration:** User data is stored in a PostgreSQL database.
- **Simple UI:** Thymeleaf templates for login, registration, and home.

## Setup Instructions

1. **Clone the Repository**
   ```sh
   git clone <repository-url>
   cd betech-login-backend
   ```

2. **Configure the Database**
   - Create a PostgreSQL database and user.
   - Update `src/main/resources/application.properties` with your database connection details:
     ```
     spring.datasource.url=jdbc:postgresql://localhost:5432/<your-db>
     spring.datasource.username=<your-username>
     spring.datasource.password=<your-password>
     spring.jpa.hibernate.ddl-auto=update
     spring.jpa.show-sql=true
     ```
   - Example SQL to create the users table (if not auto-created by JPA):
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

4. **Run the Application**
   ```sh
   mvn spring-boot:run
   ```

5. **Access the Application**
   - Open your browser and go to: [http://localhost:8080](http://localhost:8080)

## Usage

- **Register:** Go to `/register` to create a new account.
- **Login:** Go to `/login` to log in.
- **Home:** After logging in, you will be redirected to `/home`.

## Dependencies

- Spring Boot Starter Web
- Spring Boot Starter Thymeleaf
- Spring Boot Starter Data JPA
- PostgreSQL JDBC Driver

## License

This project is licensed under the MIT License. See the LICENSE file for details.