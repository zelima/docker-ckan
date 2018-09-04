FROM alpine:3.8

MAINTAINER Keitaro Inc <info@keitaro.com>

# Set CKAN version to build
ENV GIT_URL=https://github.com/ckan/ckan.git
ENV GIT_BRANCH=ckan-2.8.1

ENV APP_DIR=/srv/app
ENV SRC_DIR=/srv/app/src
ENV PIP_SRC=${SRC_DIR}
ENV CKAN_SITE_URL=http://localhost:5000
ENV CKAN__PLUGINS image_view text_view recline_view datastore datapusher harvest ckan_harvester envvars

WORKDIR ${APP_DIR}

# Install necessary packages to run CKAN
RUN apk add --no-cache git \
        git \
        curl \
        python \
        postgresql-dev \
        linux-headers \
        gcc \
        make \
        g++ \
        autoconf \
        automake \
        libtool \
        musl-dev \
        pcre-dev \
        python-dev \
        gettext \
        curl \
        postgresql-client \
        python \
	libmagic \
        apache2-utils \
        sudo \
        uwsgi \
        uwsgi-http \
        uwsgi-corerouter \
        uwsgi-python \
        py2-gevent \
        uwsgi-gevent


# Create SRC_DIR
RUN mkdir -p ${SRC_DIR} && \
    # Create nginx run dir
    mkdir -p /run/nginx && \
    # Install pip, supervisord and uwsgi
    curl -o ${SRC_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python ${SRC_DIR}/get-pip.py && \
    pip install supervisor && \
    mkdir /etc/supervisord.d && \
    #pip wheel --wheel-dir=/wheels uwsgi gevent && \
    rm -rf ${SRC_DIR}/get-pip.py

RUN echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk add --update --no-cache geos@testing geos-dev@testing py-geos@testing

COPY setup/supervisord.conf /etc

# Copy necessary scripts
COPY setup/app ${APP_DIR}

# Compile and install redis needed for harvest and CKAN 2.8
ENV REDIS_VERSION=3.2.9
ENV CKAN__HARVEST__MQ__TYPE=redis
ENV CKAN__HARVEST__MQ__HOSTNAME=localhost
ENV CKAN__HARVEST__MQ__PORT=6379
RUN apk add --no-cache linux-headers && \
    cd ${SRC_DIR} && \
    wget http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz && \
    tar xzf redis-${REDIS_VERSION}.tar.gz && \
    rm -f redis-${REDIS_VERSION}.tar.gz &&\
    cd ${SRC_DIR}/redis-${REDIS_VERSION} && \
    make && \
    cp src/redis-server /bin/redis-server && \
    rm -rf ${SRC_DIR}/redis-${REDIS_VERSION}

RUN pip install -e git+${GIT_URL}@${GIT_BRANCH}#egg=ckan && \
    cd ${SRC_DIR}/ckan && \
    cp who.ini ${APP_DIR} && \
    pip install -r requirements.txt && \
    # Install CKAN envvars to support loading config from environment variables
    pip install -e git+https://github.com/okfn/ckanext-envvars.git#egg=ckanext-envvars && \
    pip install -e git+https://github.com/ckan/ckanext-harvest.git@v1.0.0#egg=ckanext-harvest && \
    pip install -r https://raw.githubusercontent.com/ckan/ckanext-harvest/v1.0.0/pip-requirements.txt && \
    # Create and update CKAN config
    paster --plugin=ckan make-config ckan ${APP_DIR}/production.ini && \
    paster --plugin=ckan config-tool ${APP_DIR}/production.ini "ckan.plugins = ${CKAN__PLUGINS}"

RUN addgroup -g 92 -S ckan && \
    adduser -u 92 -h /srv/app -H -D -S -G ckan ckan

RUN touch /var/log/cron.log && \
    chmod 0666 /var/log/cron.log && \
    touch crontab.tmp && \
    echo '0 * * * * paster --plugin=ckanext-harvest harvester run -c /srv/app/production.ini >> /var/log/cron.log 2>&1' > crontab.tmp && \
    crontab -u ckan crontab.tmp && \
    rm -rf crontab.tmp

COPY setup/cron.conf /etc/supervisord.d/cron.conf

COPY setup ${APP_DIR}
COPY setup/harvest.conf /etc/supervisord.d/harvest.conf
COPY setup/prerun_harvest.py ${APP_DIR}/prerun_harvest.py
COPY setup/redis.conf /etc/supervisord.d/redis.conf

RUN chown ckan:ckan -R /srv/app

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=5s --retries=5 CMD curl --fail http://localhost:5000/api/3/action/status_show || exit 1

USER ckan

CMD ["/srv/app/start_ckan.sh"]
