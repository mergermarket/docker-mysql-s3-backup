FROM alpine:3.3

ENV AWSCLI_VERSION "1.10.38"
ENV PACKAGES "groff less python py-pip curl openssl ca-certificates mysql-client bash findutils"

RUN apk add --update $PACKAGES \
    && pip install awscli==$AWSCLI_VERSION \
    && apk --purge -v del py-pip \
    && rm -rf /var/cache/apk/*

ADD ./assets/dump_database.sh /usr/local/bin/
RUN test -x /usr/local/bin/dump_database.sh

ADD ./assets/sync_to_s3_test.sh /usr/local/bin/
RUN test -x /usr/local/bin/sync_to_s3_test.sh
