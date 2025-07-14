# BETECH EKS Deployment Scripts

This repository contains production-ready deployment scripts for the BETECH application on Amazon EKS, incorporating all fixes and lessons learned from troubleshooting.

## Project Structure

```
BETECH-APP-DEPLOYMENT
├── betech-login-backend      # Spring Boot backend application
│   └── README.md
├── betech-login-frontend     # React frontend application
│   └── README.md
├── betech-postgresql-db      # PostgreSQL database setup
│   └── README.md
├── eks-deployment            # Terraform infrastructure code
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── deploy.sh
│   └── ...
├── manifests                 # Kubernetes deployment manifests
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── postgres-deployment.yaml
│   ├── ingress.yaml
│   ├── secrets.yaml
│   └── ...
├── persistent-volume-claim   # Storage configuration
│   └── manifests/
├── docker-compose.yml        # Local development setup
├── deploy-eks.sh            # Main deployment script
├── validate-deployment.sh   # Validation script
└── README.md                # This file
```

## Components

- **betech-login-backend:** Spring Boot REST API for user registration and login, using PostgreSQL.
- **betech-login-frontend:** React frontend for user interaction.
- **docker-compose.yml:** Orchestrates backend, frontend, and database containers.
- **betech-postgresql-db:** (Optional) SQL scripts and instructions for manual PostgreSQL setup.

## Deployment Overview

1. **Clone the Repository**
   ```sh
   git clone <repository-url>
   cd BETECH-APP-DEPLOYMENT
   ```

2. **Configure Environment Variables**
   - The backend uses environment variables for database connection, set in `docker-compose.yml`:
     - `SPRING_DATASOURCE_URL`
     - `SPRING_DATASOURCE_USERNAME`
     - `SPRING_DATASOURCE_PASSWORD`
     - `SPRING_JPA_HIBERNATE_DDL_AUTO`

3. **Start All Services**
   ```sh
   docker-compose up --build
   ```
   - This will start:
     - PostgreSQL database (`betechnet-postgres`)
     - Spring Boot backend (`betechnet-backend`)
     - React frontend (`betechnet-frontend`)

4. **Access the Application**
   - **Frontend:** [http://localhost:3000](http://localhost:3000) or your server's public IP.
   - **Backend API:** [http://localhost:8080/api](http://localhost:8080/api) (typically accessed by the frontend).
   - **Database:** Exposed on port 5432 for development.

## Prerequisites

- Docker and Docker Compose installed

## Usage

- Register and log in via the frontend.
- User data is securely stored in PostgreSQL.
- The backend exposes REST endpoints at `/api/register` and `/api/login`.
- CORS is configured to allow requests from both `localhost:3000` and your public frontend domain.

## Notes

- All configuration (database credentials, CORS origins, etc.) is managed via environment variables and `application.properties`.
- For production, review and restrict CORS and environment variable usage as needed.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
