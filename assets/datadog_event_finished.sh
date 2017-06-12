#!/bin/bash

SCRIPT_DIR="$(dirname $0)"

if [ -n "${DATADOG_API_KEY}" ]; then
  echo "Sending event mysql-s3-backup.finished[${DATADOG_TAGS}] to DataDog"
  ${SCRIPT_DIR}/datadog-notify.sh mysql-s3-backup.finished "Mysql Dump and Sync to S3 has finished" info "${DATADOG_TAGS:-}"
fi
