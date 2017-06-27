#!/bin/bash
set -e -u -o pipefail

SCRIPT_NAME=$0


help() {
    cat <<EOF
Usage:
	DATABASE_TYPE=mysql \
	DATABASE_HOSTNAME=server.mysql.company.com \
	DATABASE_PORT=3306 \
	DATABASE_DB_NAME=foobar \
	DATABASE_USERNAME=foobar \
	DATABASE_PASSWORD=jellyfish \
	RETENTION=30 \
	DUMPS_PATH=/data/mysql \
		${SCRIPT_NAME}

It will dump the provided database:
 - in the directory \${DUMPS_PATH}.
 - will keep a naming like: \${DATABASE_DB_NAME}-2017-02-03-17-03.
 - will delete any file older than \${RETENTION} days
EOF
}

dump_mysql() {
	echo "Dumping mysql://${DATABASE_USERNAME}@${DATABASE_HOSTNAME}:${DATABASE_PORT}/${DATABASE_DB_NAME} to ${DUMPFILE}"
	mkdir -p "${DUMPS_PATH}"
	mysqldump \
		--protocol=TCP \
		"--host=${DATABASE_HOSTNAME}" \
		"--port=${DATABASE_PORT}"\
		"--user=${DATABASE_USERNAME}" \
		"--password=${DATABASE_PASSWORD}" \
		--add-drop-database \
		--skip-add-drop-table \
		--skip-add-locks \
		--skip-disable-keys \
		--skip-set-charset \
		--compress \
		--single-transaction \
		"${DATABASE_DB_NAME}" | gzip -c - > ${DUMPFILE}
	echo -n "Done: "
	ls -l "${DUMPFILE}"
}

delete_old_dumps() {
	# This line will:
	# 1. Find for all the dumps and print the timestamp and name (-printf "%T@ %p\n")
	# 2. Order by tiemstamp, increasing
	# 3. the only the name (cut)
	# 4. Drop the last ${RETENTION} lines.
	# 5. Delete the rest of the files if any.
	find "${DUMPS_PATH}" \
	    -name 'db-dump-*.sql.gz' \
	    -printf "%T@ %p\n" | \
		sort -n | cut -f 2- -d ' ' | head -n "-${RETENTION}" | \
		    xargs -r rm -vf
}

DUMPFILE="${DUMPS_PATH}/db-dump-${DATABASE_DB_NAME}-$(date +%Y-%m-%d-%H-%M-%S).sql.gz"
DATABASE_PORT="${DATABASE_PORT:-3306}"

case "${DATABASE_TYPE:-mysql}" in
	mysql)
		dump_mysql "${DUMPFILE}"
	;;
	*)
		echo "ERROR: Unsupported DB type '${DATABASE_TYPE}'" 1>&2
		exit 1
	;;
esac

delete_old_dumps


