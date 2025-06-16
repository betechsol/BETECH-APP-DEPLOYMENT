# BETECH App Deployment

This repository contains all components and deployment instructions for the BETECH Tomcat Login Application, including the backend, frontend, and database setup.

## Project Structure

```
BETECH-APP-DEPLOYMENT
├── tomcat-login-app         # Java Servlet backend application
│   └── README.md
├── tomcat-login-frontend    # React frontend application
│   └── README.md
├── postgresql-db            # PostgreSQL database setup scripts
│   └── README.md
└── README.md                # This file
```

## Components

- **tomcat-login-app:** Java Servlet backend for user registration and login, using PostgreSQL.
- **tomcat-login-frontend:** React frontend for user interaction.
- **postgresql-db:** SQL scripts and instructions for setting up the required PostgreSQL database.

## Deployment Overview

1. **Set Up the Database**
   - Follow instructions in `postgresql-db/README.md` to install PostgreSQL, create the database, user, and tables.

2. **Configure and Deploy the Backend**
   - See `tomcat-login-app/README.md` for building and deploying the Java backend to Tomcat.
   - Update database connection details in `src/main/resources/db.properties`.

3. **Configure and Run the Frontend**
   - See `tomcat-login-frontend/README.md` for installing dependencies and running the React app.
   - Ensure the frontend API endpoints point to your backend server.

## Prerequisites

- Java 8+ and Maven
- Node.js and npm
- PostgreSQL
- Apache Tomcat

## Usage

- Register and log in via the frontend.
- User data is securely stored in PostgreSQL.
- Sessions are managed by the backend.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
