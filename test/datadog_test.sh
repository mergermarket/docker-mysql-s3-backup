#!/usr/bin/env bash

set -e -u -o pipefail

PROJECT_DIR="$(dirname $0)/.."
SCRIPT_DIR="$(dirname $0)"

source "${SCRIPT_DIR}/common.sh"

# before all
export TEMPDIR_ROOT="$(mktemp -d)"
trap "{ rm -rf ${TEMPDIR_ROOT:-/tmp/dummy}; }" EXIT INT TERM


# Mock curl and aws commands
mkdir "${TEMPDIR_ROOT}/bin"
cat > "${TEMPDIR_ROOT}/bin/curl" <<"EOF"
#!/bin/bash
for i in "$@"; do
	echo "${i}"
done
touch "${TEMPDIR_ROOT}/curl_called"
EOF
chmod +x "${TEMPDIR_ROOT}"/bin/*
export PATH="${TEMPDIR_ROOT}/bin:${PATH}"

_before_each() {
	true
}

_after_each() {
	true
}

it_does_not_send_event_if_datadog_key_missing() {
	export DATADOG_API_KEY=
	"${PROJECT_DIR}/assets/datadog_event_finished.sh" > /dev/null
 	if test -f "${TEMPDIR_ROOT}/curl_called"; then
 		echo "Error: curl should not be called"
 		return 1
 	fi
}

it_does_sends_event_to_datadog() {
	export DATADOG_API_KEY=__datadog_api_key
	output=$("${PROJECT_DIR}/assets/datadog_event_finished.sh")

 	if ! test -f "${TEMPDIR_ROOT}/curl_called"; then
 		echo "Error: curl should be called"
 		return 1
 	fi
 	echo "${output}" | grep -q 'https://app.datadoghq.com/api/v1/events?api_key=__datadog_api_key' || return $?
 	echo "${output}" | grep -q '"title": "mysql-s3-backup.finished"' || return $?
 	echo "${output}" | grep -q '"text": "Mysql Dump and Sync to S3 has finished"' || return $?
 	echo "${output}" | grep -q 'Content-type: application/json' || return $?
}

it_does_send_the_tags() {
set -e -u -o pipefail
	export DATADOG_API_KEY=__datadog_api_key
	export DATADOG_TAGS="tag1:val1 tag2:val2"
	output=$("${PROJECT_DIR}/assets/datadog_event_finished.sh")

 	if ! test -f "${TEMPDIR_ROOT}/curl_called"; then
 		echo "Error: curl should be called"
 		return 1
 	fi
 	echo "${output}" | grep -q '["tag1:val1","tag2:val2"]' || return $?
 	echo "${output}" | grep -q '"title": "mysql-s3-backup.finished"' || return $?
 	echo "${output}" | grep -q '"text": "Mysql Dump and Sync to S3 has finished"' || return $?
}

_run it_does_not_send_event_if_datadog_key_missing
_run it_does_sends_event_to_datadog
_run it_does_send_the_tags
