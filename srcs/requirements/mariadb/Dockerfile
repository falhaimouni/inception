FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y mariadb-server\
    && rm -rf /var/lib/apt/lists/*

COPY tools/mariadb.sh .

RUN chmod +x mariadb.sh

ENTRYPOINT ["./mariadb.sh"]