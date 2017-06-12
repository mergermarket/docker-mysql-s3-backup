#!/usr/bin/env bash

set -e -o pipefail -u

SCRIPT_DIR="$(dirname $0)"
"${SCRIPT_DIR}"/dump_database_test.sh
"${SCRIPT_DIR}"/sync_to_s3_test.sh
"${SCRIPT_DIR}"/datadog_test.sh
