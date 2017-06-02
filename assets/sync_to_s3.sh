#!/usr/bin/env bash
set -e -u -o pipefail

SCRIPT_NAME=$0

help() {
    cat <<EOF
Usage:
	S3_BUCKET_NAME=my_bucket \
	S3_BUCKET_PATH=/backup/jira/live \
	SYNC_ORIGIN_PATH=/data \
		${SCRIPT_NAME}

Other optional variables:
	S3_ENDPOINT=...

I will copy all the files from /data into the given S3 bucket.
EOF
}

if [ -z "${SYNC_ORIGIN_PATH}" ] && ! [ -d "${SYNC_ORIGIN_PATH}" ]; then
    echo "ERROR: \${SYNC_ORIGIN_PATH}='${SYNC_ORIGIN_PATH}' is not a valid directory'"
    exit 1
fi

do_sync() {
    aws s3 sync \
    	--delete \
    	${S3_ENDPOINT:+--endpoint-url ${S3_ENDPOINT}} \
    	"${SYNC_ORIGIN_PATH}" \
    	"s3://${S3_BUCKET_NAME}/${S3_BUCKET_PATH}"
}

do_sync
