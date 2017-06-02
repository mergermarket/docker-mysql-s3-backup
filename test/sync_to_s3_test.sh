#!/usr/bin/env bash

set -e -u -o pipefail

PROJECT_DIR="$(dirname $0)/.."
SCRIPT_DIR="$(dirname $0)"

source "${SCRIPT_DIR}/common.sh"

# Helpers
_aws() {
	aws ${S3_ENDPOINT:+--endpoint-url ${S3_ENDPOINT}} "$@"
}

# before all
TEMPDIR_ROOT="$(mktemp -d)"
trap "{ rm -rf ${TEMPDIR_ROOT:-/tmp/dummy}; }" EXIT INT TERM

"${SCRIPT_DIR}"/helpers/wait-for-it.sh "${S3_ENDPOINT##http://}"

_before_each() {
	export AWS_SESSION_TOKEN=dummy
	export AWS_SECRET_ACCESS_KEY=dummy
	export AWS_ACCESS_KEY_ID=dummy

	export TEMPDIR=$(mktemp -d "${TEMPDIR_ROOT}/tests.XXXXXX")
	export TEST_BUCKET_NAME="test_bucket_$(date +%s)_${RANDOM}"
	echo -n "Creating bucket... "
    time _aws s3api create-bucket \
		--bucket "${TEST_BUCKET_NAME}"
	echo "done"
}

_after_each() {
	true
}


_test_files() {
	for d1 in {foo,bar}; do
		for d2 in {a,b,c}/{1,2,3}; do
			echo "$d1/$d2"/file{1,2}
		done
		echo "$d1"/other_file{1,2}
	done
}

_create_test_dir(){
	root_dir=$1
	for f in $(_test_files); do
		mkdir -p "$root_dir/$(dirname $f)"
		touch "$root_dir/${f}"
	done
}

it_syncs_a_complete_directory() {
	export S3_BUCKET_NAME="${TEST_BUCKET_NAME}"
	export S3_BUCKET_PATH="backup/test"
	export S3_ORIGIN_PATH="${TEMPDIR}/data"
	_create_test_dir "${S3_ORIGIN_PATH}"

	"${PROJECT_DIR}/assets/sync_to_s3.sh"

	sleep 1
	for f in $(_test_files); do
		if ! _aws s3 ls "s3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH}/$f" > /dev/null; then
			echo "Did not copy 's3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH}/$f'"
			return 1
		fi
	done
}

it_deletes_old_files() {
	export S3_BUCKET_NAME="${TEST_BUCKET_NAME}"
	export S3_BUCKET_PATH="/backup/test"
	export S3_ORIGIN_PATH="${TEMPDIR}/data"
	_create_test_dir "${S3_ORIGIN_PATH}"

	"${PROJECT_DIR}/assets/sync_to_s3.sh"
	for f in foo/other_file1 foo/a/3/file2; do
		rm "${S3_ORIGIN_PATH}/$f"
	done
	"${PROJECT_DIR}/assets/sync_to_s3.sh"

	for f in foo/other_file1 foo/a/3/file2; do
		! _aws s3 ls "s3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH}/$f" > /dev/null
	done
}

_run it_syncs_a_complete_directory
_run it_deletes_old_files
