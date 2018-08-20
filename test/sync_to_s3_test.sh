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

echo "Waiting S3 localstack to warm up..."
sleep 5
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
	export SYNC_ORIGIN_PATH="${TEMPDIR}/data"
	_create_test_dir "${SYNC_ORIGIN_PATH}"

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
	export SYNC_ORIGIN_PATH="${TEMPDIR}/data"
	_create_test_dir "${SYNC_ORIGIN_PATH}"

	"${PROJECT_DIR}/assets/sync_to_s3.sh"
	for f in foo/other_file1 foo/a/3/file2; do
		rm "${SYNC_ORIGIN_PATH}/$f"
	done
	"${PROJECT_DIR}/assets/sync_to_s3.sh"

	for f in foo/other_file1 foo/a/3/file2; do
		! _aws s3 ls "s3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH}/$f" > /dev/null
	done
}

it_does_not_sync_the_exclude_files() {
	export S3_BUCKET_NAME="${TEST_BUCKET_NAME}"
	export S3_BUCKET_PATH="/backup/test"
	export SYNC_ORIGIN_PATH="${TEMPDIR}/data"
	export SYNC_EXCLUDE="foo/c/*"
	_create_test_dir "${SYNC_ORIGIN_PATH}"

	"${PROJECT_DIR}/assets/sync_to_s3.sh"

	for f in $(_test_files); do
	  case $f in
	  foo/c/*)
	    if _aws s3 ls "s3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH}/$f" > /dev/null; then
	      echo "Error: did copy 's3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH}/$f'"
	      return 1
	    fi
	  ;;
	  *)
	    if ! _aws s3 ls "s3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH}/$f" > /dev/null; then
	      echo "Did not copy 's3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH}/$f'"
	      return 1
	    fi
          ;;
          esac
	done
}

it_loads_the_aws_credentials_from_container_role() {
	export S3_BUCKET_NAME="${TEST_BUCKET_NAME}"
	export S3_BUCKET_PATH="/backup/test"
	export SYNC_ORIGIN_PATH="${TEMPDIR}/data"
	export AWS_CONTAINER_CREDENTIALS_RELATIVE_URI="/v2/credentials/82ece582-9599-454e-8dd6-9a673aee2a72"

	# Mock curl and aws commands
	mkdir "${TEMPDIR}/bin"
	cat > "${TEMPDIR}/bin/curl" <<"EOF"
#!/bin/sh
cat <<FOE
{
  "RoleArn":"arn:aws:iam::733578946173:role/aslive-platform-crowd-s3-backup00c832349c4af0505ca1bfe870",
  "AccessKeyId":"__access_key",
  "SecretAccessKey":"__secret_access_key",
  "Token":"__session_token",
  "Expiration":"2017-06-07T23:00:21Z"
}
FOE
EOF
	cat > "${TEMPDIR}/bin/aws" <<"EOF"
#!/bin/sh
env | grep AWS
EOF

	chmod +x "${TEMPDIR}"/bin/*
	export PATH="${TEMPDIR}/bin:${PATH}"

	output=$("${PROJECT_DIR}/assets/sync_to_s3.sh")

	echo "${output}" | grep -q 'AWS_ACCESS_KEY_ID=__access_key'
	echo "${output}" | grep -q 'AWS_SECRET_ACCESS_KEY=__secret_access_key'
	echo "${output}" | grep -q 'AWS_SESSION_TOKEN=__session_token'
}

it_removes_duplicated_slashes_in_s3_target() {
	export S3_BUCKET_NAME="${TEST_BUCKET_NAME}"
	export S3_BUCKET_PATH="//backup///test/"
	export S3_BUCKET_PATH_SIMPLIFIED="backup/test"
	export SYNC_ORIGIN_PATH="${TEMPDIR}/data"
	_create_test_dir "${SYNC_ORIGIN_PATH}"

	"${PROJECT_DIR}/assets/sync_to_s3.sh"

	sleep 1
	for f in $(_test_files); do
		if ! _aws s3 ls "s3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH_SIMPLIFIED}/$f" > /dev/null; then
			echo "Did not copy 's3://${TEST_BUCKET_NAME}/${S3_BUCKET_PATH_SIMPLIFIED}/$f'"
			return 1
		fi
	done
}


_run it_syncs_a_complete_directory
_run it_deletes_old_files
_run it_does_not_sync_the_exclude_files
_run it_loads_the_aws_credentials_from_container_role
_run it_removes_duplicated_slashes_in_s3_target
