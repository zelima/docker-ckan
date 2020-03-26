##################
### Build CKAN ###
##################
FROM alpine:3.11 as ckanbuild

# Set CKAN version to build
ENV GIT_URL=https://github.com/ckan/ckan.git
ENV GIT_TAG=ckan-2.8.3

# Set src dirs
ENV SRC_DIR=/srv/app/src
ENV PIP_SRC=${SRC_DIR}

WORKDIR ${SRC_DIR}

# Packages to build CKAN requirements and plugins
RUN apk add --no-cache \
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
        pcre \
        python-dev \
        openssl-dev \
        libffi-dev

# Create the src directory
RUN mkdir -p ${SRC_DIR}

# Install pip
RUN curl -o ${SRC_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python ${SRC_DIR}/get-pip.py

# Fetch and build CKAN and requirements
RUN pip install -e git+${GIT_URL}@${GIT_TAG}#egg=ckan
RUN rm -rf /srv/app/src/ckan/.git
RUN pip wheel --wheel-dir=/wheels -r ckan/requirements.txt
RUN pip wheel --wheel-dir=/wheels uwsgi gevent

############
### MAIN ###
############
FROM alpine:3.11

MAINTAINER Keitaro Inc <info@keitaro.com>

ENV APP_DIR=/srv/app
ENV SRC_DIR=/srv/app/src
ENV PIP_SRC=${SRC_DIR}
ENV CKAN_SITE_URL=http://localhost:5000
ENV CKAN__PLUGINS envvars image_view text_view recline_view datastore datapusher harvest ckan_harvester
ENV TZ Europe/Skopje

WORKDIR ${APP_DIR}

# Install necessary packages to run CKAN
RUN apk add --no-cache git \
        bash \
        gettext \
        curl \
        postgresql-client \
        python \
        libmagic \
        pcre \
        tzdata \
        linux-headers \
        gcc \
        make \
        g++ \
        python-dev \
        openssl-dev \
        libffi-dev \
        apache2-utils && \
    # Create SRC_DIR
    mkdir -p ${SRC_DIR}

# Install pip
RUN curl -o ${SRC_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python ${SRC_DIR}/get-pip.py

# Get artifacts from build stages
COPY --from=ckanbuild /wheels /srv/app/wheels
COPY --from=ckanbuild /srv/app/src/ckan /srv/app/src/ckan

# Copy necessary scripts
COPY setup/app ${APP_DIR}

# Additional install steps for build stages artifacts and supervisor
RUN pip install --no-index --find-links=/srv/app/wheels uwsgi gevent && \
    pip install supervisor && \
    mkdir /etc/supervisord.d

# Create a local user and group to run the app
RUN addgroup -g 92 -S ckan && \
    adduser -u 92 -h /srv/app -H -D -S -G ckan ckan

# Install CKAN
RUN pip install -e /srv/app/src/ckan && \
    cd ${SRC_DIR}/ckan && \
    cp who.ini ${APP_DIR} && \
    pip install --no-index --find-links=/srv/app/wheels -r requirements.txt && \
    # Install CKAN envvars to support loading config from environment variables
    pip install -e git+https://github.com/okfn/ckanext-envvars.git@0.0.1#egg=ckanext-envvars && \
    pip install -e git+https://github.com/ckan/ckanext-harvest.git@v1.2.0#egg=ckanext-harvest && \
    pip install -r https://raw.githubusercontent.com/ckan/ckanext-harvest/v1.2.0/pip-requirements.txt && \
    # Create and update CKAN config
    paster --plugin=ckan make-config ckan ${APP_DIR}/production.ini && \
    paster --plugin=ckan config-tool ${APP_DIR}/production.ini "ckan.plugins = ${CKAN__PLUGINS}"

RUN touch /var/log/cron.log && \
    chmod 0666 /var/log/cron.log && \
    touch crontab.tmp && \
    echo '0 * * * * paster --plugin=ckanext-harvest harvester run -c /srv/app/production.ini >> /var/log/cron.log 2>&1' > crontab.tmp && \
    crontab -u ckan crontab.tmp && \
    rm -rf crontab.tmp

COPY setup/supervisord.conf /etc/supervisord.conf
COPY setup/cron.conf /etc/supervisord.d/cron.conf

COPY setup ${APP_DIR}
COPY setup/harvest.conf /etc/supervisord.d/harvest.conf
COPY setup/prerun_harvest.py ${APP_DIR}/prerun_harvest.py
    
# Change ownership to app user
RUN chown -R ckan:ckan /srv/app

# Remove wheels
RUN rm -rf /srv/app/wheels

# Create entrypoint directory for children image scripts
ONBUILD RUN mkdir docker-entrypoint.d

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=5s --retries=5 CMD curl --fail http://localhost:5000/api/3/action/status_show || exit 1

USER ckan

CMD ["/srv/app/start_ckan.sh"]
