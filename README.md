Docker Mysql S3 Backups
-----------------------

Container to perform MySQL dumps and sync a local directory to a remote S3 bucket.

It includes:


`/usr/local/bin/dump_database.sh`:

```
Usage:
	DATABASE_TYPE=mysql \
	DATABASE_HOSTNAME=server.mysql.company.com \
	DATABASE_PORT=3306 \
	DATABASE_DB_NAME=jira \
	DATABASE_USERNAME=jira \
	DATABASE_PASSWORD=jellyfish \
	RETENTION=30 \
	DUMPS_PATH=/data/mysql \
		dump_database.sh

It will dump the provided database:
 - in the directory ${DUMPS_PATH}.
 - will keep a naming like: ${DATABASE_DB_NAME}-2017-02-03-17-03.
 - will delete any file older than ${RETENTION} days
```

`/usr/local/bin/sync_to_s3.sh`:

```
Usage:
	S3_BUCKET_NAME=my_bucket \
	S3_ORIGIN_PATH=/data \
		${SCRIPT_NAME}

Other optional variables:
	S3_ENDPOINT=...

I will copy all the files from /data into the given S3 bucket.
```

