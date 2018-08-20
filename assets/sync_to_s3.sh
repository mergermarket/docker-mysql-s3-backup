#!/usr/bin/env bash
set -e -u -o pipefail

SCRIPT_NAME=$0

help() {
    cat <<EOF
Usage:
	S3_BUCKET_NAME=my_bucket \
	S3_BUCKET_PATH=/backup/foobar/live \
	SYNC_ORIGIN_PATH=/data \
		${SCRIPT_NAME}

Other optional variables:
	S3_ENDPOINT=...  - S3 endpoint to connect to
	SYNC_EXCLUDE=/data/dir/* - Directory to exclude

I will copy all the files from /data into the given S3 bucket.
EOF
}

if [ -z "${SYNC_ORIGIN_PATH}" ] && ! [ -d "${SYNC_ORIGIN_PATH}" ]; then
    echo "ERROR: \${SYNC_ORIGIN_PATH}='${SYNC_ORIGIN_PATH}' is not a valid directory'"
    exit 1
fi

remove_double_slashes() {
    local a="$1"
    local b=""
    while [ "$b" != "$a" ]; do
	b="$a"; a="${b//\/\//\/}";
    done;
    echo "$a"
}

do_sync() {
    target_path=s3://$(remove_double_slashes "${S3_BUCKET_NAME}/${S3_BUCKET_PATH}")
    aws s3 sync \
    	--delete \
    	${S3_ENDPOINT:+--endpoint-url ${S3_ENDPOINT}} \
	${SYNC_EXCLUDE:+--exclude "${SYNC_EXCLUDE}"} \
    	"${SYNC_ORIGIN_PATH}" \
	"${target_path}"
}

load_aws_credentials(){
    if [ -n "${AWS_CONTAINER_CREDENTIALS_RELATIVE_URI:-}" ]; then
	eval $(curl -qs 169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI | jq -r '"export AWS_ACCESS_KEY_ID=\( .AccessKeyId )\nexport AWS_SECRET_ACCESS_KEY=\( .SecretAccessKey )\nexport AWS_SESSION_TOKEN=\( .Token )"')
    fi
}

load_aws_credentials
# aws s3 sync sometimes doesn't work if the files change, so this gives more chance of success
do_sync || do_sync || do_sync
