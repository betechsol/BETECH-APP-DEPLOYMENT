FROM postgres:14

ENV POSTGRES_DB=BETECH_DB
ENV POSTGRES_USER=admin
ENV POSTGRES_PASSWORD=admin123
ENV PGDATA=/var/lib/postgresql/data/pgdata

COPY init.sql /docker-entrypoint-initdb.d/