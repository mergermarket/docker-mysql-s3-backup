#!/bin/sh

cd test

trap "{ docker-compose stop; docker-compose rm -fva; }" EXIT INT TERM

docker-compose build
docker-compose run --rm mysql-s3-backup /code/test/all_test.sh
