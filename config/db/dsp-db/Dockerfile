FROM postgis/postgis:16-3.4
# Init SQL runs only on first start (empty data volume).
COPY *.sql /docker-entrypoint-initdb.d/
