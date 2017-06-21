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
	DATABASE_DB_NAME=foobar \
	DATABASE_USERNAME=foobar \
	DATABASE_PASSWORD=jellyfish \
	RETENTION=30 \
	DUMPS_PATH=/data/mysql \
		dump_database.sh

It will dump the provided database:
 - in the directory ${DUMPS_PATH}.
 - will keep a naming like: ${DATABASE_DB_NAME}-2017-02-03-17-03.
 - will keep the ${RETENTION} dumps more recent
```

`/usr/local/bin/sync_to_s3.sh`:

```
Usage:
	S3_BUCKET_NAME=my_bucket \
	S3_BUCKET_PATH=/backup/foobar/live \
	SYNC_ORIGIN_PATH=/data \
		sync_to_s3.sh

Other optional variables:
	S3_ENDPOINT=...  - S3 endpoint to connect to
	SYNC_EXCLUDE=/data/dir/* - Directory to exclude

I will copy all the files from /data into the given S3 bucket.
```

Datadog integration:

If `$DATADOG_API_KEY` is set, an event will be sent when both script finishes. Variables:

  * `$DATADOG_API_KEY` Datadog API key to use
  * `$DATADOG_TAGS` tags to send in the event.

Currently we send and unique event `mysql-s3-backup.finished`
