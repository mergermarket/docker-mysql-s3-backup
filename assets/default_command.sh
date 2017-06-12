#!/usr/bin/env bash

set -e

SCRIPTS_PATH=${SCRIPTS_PATH:-/usr/local/bin}

trap 'echo -e "\nBackup job finished with exit code: $?"'  EXIT INT TERM

"${SCRIPTS_PATH}"/dump_database.sh
"${SCRIPTS_PATH}"/sync_to_s3.sh
"${SCRIPTS_PATH}"/datadog_event_finished.sh
