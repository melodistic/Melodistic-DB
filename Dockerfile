FROM postgres:latest
ENV POSTGRES_DB=melodistic
ENV POSTGRES_USER=melodistic
ENV POSTGRES_PASSWORD=melodistic-pwd

COPY entrypoint.sql /docker-entrypoint-initdb.d/

EXPOSE 5432