FROM debian:bullseye

RUN apt-get update && apt-get install -y \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*

COPY conf/my.cnf /etc/mysql/my.cnf
COPY tools/script.sh /tmp/script.sh

RUN chmod +x /tmp/script.sh

EXPOSE 3306

CMD ["sh", "/tmp/script.sh"]