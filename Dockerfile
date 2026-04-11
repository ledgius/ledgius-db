FROM postgres:16-bookworm

# Copy tenant migrations for init
COPY tenant/ /docker-entrypoint-initdb.d/migrations/

EXPOSE 5432
