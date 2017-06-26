#!/bin/bash

set -e -u -o pipefail

PROJECT_DIR="$(dirname $0)/.."
SCRIPT_DIR="$(dirname $0)"

source "${SCRIPT_DIR}/common.sh"

export DATABASE_TYPE=mysql
export DATABASE_HOSTNAME=${DATABASE_HOSTNAME:-mysql}
export DATABASE_PORT=${DATABASE_PORT:-3306}
export DATABASE_DB_NAME=${DATABASE_DB_NAME:-foobar}
export DATABASE_USERNAME=${DATABASE_USERNAME:-foobar}
export DATABASE_PASSWORD=${DATABASE_PASSWORD:-jellyfish}

# Helpers
_mysql() {
	mysql \
		--protocol=TCP \
		"--host=${DATABASE_HOSTNAME}" \
		"--port=${DATABASE_PORT}"\
		"--user=${DATABASE_USERNAME}" \
		"--password=${DATABASE_PASSWORD}" \
		"${DATABASE_DB_NAME}" \
		--skip-column-names \
		--batch \
		--raw \
		"$@"
}


# before all
TEMPDIR_ROOT="$(mktemp -d)"
trap "{ rm -rf ${TEMPDIR_ROOT:-/tmp/dummy}; }" EXIT INT TERM

"${SCRIPT_DIR}"/helpers/wait-for-it.sh "${DATABASE_HOSTNAME:-mysql}:${DATABASE_PORT:-3306}"


_before_each() {
	TEMPDIR=$(mktemp -d "${TEMPDIR_ROOT}/tests.XXXXXX")
	_mysql -e "drop database $DATABASE_DB_NAME; create database $DATABASE_DB_NAME;"
	_mysql -e "
		set foreign_key_checks=0;
		CREATE TABLE pet (
			name VARCHAR(20),
			owner VARCHAR(20),
			species VARCHAR(20),
			sex CHAR(1),
			birth DATE,
			death DATE,
			FOREIGN KEY (owner) REFERENCES theowner (name)
		) ENGINE=INNODB;
		CREATE TABLE theowner (
			name VARCHAR(20) NOT NULL,
			address VARCHAR(20),
			PRIMARY KEY (name)
		) ENGINE=INNODB;
		set foreign_key_checks=1;
		"
	_mysql -e "INSERT INTO theowner VALUES ('Diane','123 High Street');"
	_mysql -e "INSERT INTO theowner VALUES ('Jhon','222 1st Avenue');"
	_mysql -e "INSERT INTO pet VALUES ('Puffball','Diane','hamster','f','1999-03-30',NULL);"
	_mysql -e "INSERT INTO pet VALUES ('Daisy','Jhon','dog','m','2013-04-31','2015-04-31');"
}

_after_each() {
	true
}

it_creates_a_sqldump_with_valid_name() {
	export DUMPS_PATH="${TEMPDIR}/dumps"
	"${PROJECT_DIR}/assets/dump_database.sh"

	test "$(find "${DUMPS_PATH}" -name 'db-dump-*.sql.gz' | wc -l)" == 1
	test "$(find "${DUMPS_PATH}" -regex '.*/db-dump-[a-zA-Z0-9]+-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\.sql\.gz.*' | wc -l)" == 1
}


it_creates_a_valid_sqldump() {
	export DUMPS_PATH="${TEMPDIR}/dumps"
	"${PROJECT_DIR}/assets/dump_database.sh"
	dump_file=$(find "${DUMPS_PATH}" -name 'db-dump-*.sql.gz' | head -n1)

	_mysql -e "drop database $DATABASE_DB_NAME; create database $DATABASE_DB_NAME;"

	cat ${dump_file} | gunzip -c - | _mysql
	test "$(_mysql -e "SELECT COUNT(*) FROM pet;")" == 2
}

it_creates_a_valid_sqldump() {
	export DUMPS_PATH="${TEMPDIR}/dumps"
	"${PROJECT_DIR}/assets/dump_database.sh"
	dump_file=$(find "${DUMPS_PATH}" -name 'db-dump-*.sql.gz' | head -n1)

	_mysql -e "drop database $DATABASE_DB_NAME; create database $DATABASE_DB_NAME;"

	cat ${dump_file} | gunzip -c - | _mysql
	test "$(_mysql -e "SELECT COUNT(*) FROM pet;")" == 2
}

it_deletes_old_dumps() {
	export DUMPS_PATH="${TEMPDIR}/dumps"
	export RETENTION=30

	mkdir -p "${DUMPS_PATH}"
	for i in $(seq 35); do
		timestamp="$(( $(date +%s) - ${i} * 24 * 60 * 60 ))"
		touch -d @${timestamp} "${DUMPS_PATH}/db-dump-${DATABASE_DB_NAME}-$(date -d @${timestamp} +%Y-%m-%d-%H-%M-%S).sql.gz"
		timestamp="$(( $timestamp + 12 * 60 * 60 ))"
		touch -d @${timestamp} "${DUMPS_PATH}/db-dump-${DATABASE_DB_NAME}-$(date -d @${timestamp} +%Y-%m-%d-%H-%M-%S).sql.gz"
	done

	"${PROJECT_DIR}/assets/dump_database.sh"

	remanining_dumps="$(find "${DUMPS_PATH}" -name 'db-dump-*.sql.gz' | wc -l)"
	expected_dumps="${RETENTION}"
	if test "${remanining_dumps}" != ${expected_dumps}; then
		echo "Fail: # of dumps ${remanining_dumps} do not match expected ${expected_dumps}"
		return 1
	fi

	dumps_older_than_15_days="$(find "${DUMPS_PATH}" -name 'db-dump-*.sql.gz' -mtime +15)"
	if test -n "${dumps_older_than_15_days}"; then
		echo "Fail: there are tests older than 15 days: ${dumps_older_than_15_days}"
		return 1
	fi
}

_run it_creates_a_sqldump_with_valid_name
_run it_creates_a_valid_sqldump
_run it_deletes_old_dumps
