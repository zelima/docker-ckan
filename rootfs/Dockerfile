FROM keitaro/base:0.1

MAINTAINER Keitaro Inc <info@keitaro.info>

ENV APP_DIR=/srv/app
ENV SRC_DIR=/srv/app/src
ENV PIP_SRC=${SRC_DIR}
ENV GIT_URL=https://github.com/ckan/ckan.git
ENV GIT_BRANCH=dev-v2.7
ENV CKAN_SITE_URL=http://localhost:5000
ENV CKAN__PLUGINS image_view text_view recline_view datastore datapusher envvars

WORKDIR ${APP_DIR}

#########################
### Base docker layer ###
#########################
# Install necessary packages to run CKAN
RUN apk --update add --no-cache git \
        gettext \
        postgresql-client \
        python \
        nginx \
        apache2-utils \
        libxml2 \
        libxslt \
        libmagic && \
    # Packages to build CKAN requirements and plugins
    apk add --no-cache --virtual .build-deps \
        postgresql-dev \
        gcc \
        make \
        g++ \
        autoconf \
        automake \
	libtool \
        musl-dev \
        python-dev \
        libxml2-dev \
        libxslt-dev && \
    # Create SRC_DIR
    mkdir -p ${SRC_DIR} && \
    # Create nginx run dir
    mkdir -p /run/nginx && \
    # Install pip and gunicorn
    curl -o ${SRC_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python ${SRC_DIR}/get-pip.py && \
    pip install gunicorn gevent && \
    pip install supervisor && \
    mkdir /etc/supervisord.d && \
    rm -rf ${SRC_DIR}/get-pip.py

############################
### libgeos docker layer ###
############################
# Build and install libgeos to support geospatial
RUN git clone -b 3.6.0 --depth=1 --single-branch https://git.osgeo.org/gogs/geos/geos.git ${SRC_DIR}/geos && \
    cd ${SRC_DIR}/geos && \
    ./autogen.sh && \
    ./configure --prefix /usr && \
    make -j2 && \
    make install && \
    rm -rf ${SRC_DIR}/geos

###########################
### redis docker layers ###
###########################
# Compile and install redis needed for harvest and CKAN 2.7
ENV REDIS_VERSION=3.2.9
ENV CKAN__HARVEST__MQ__TYPE=redis
ENV CKAN__HARVEST__MQ__HOSTNAME=localhost
ENV CKAN__HARVEST__MQ__PORT=6379
RUN apk add --no-cache linux-headers && \
    cd ${SRC_DIR} && \
    wget http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz && \
    tar xzf redis-${REDIS_VERSION}.tar.gz && \
    rm -f redis-${REDIS_VERSION}.tar.gz && \
    cd redis-${REDIS_VERSION} && \
    make && \
    cp src/redis-server /bin/redis-server && \
    rm -rf ${SRC_DIR}/redis-${REDIS_VERSION}


#########################
### CKAN docker layer ###
#########################
# Install CKAN
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

COPY setup/supervisord.conf /etc
COPY setup ${APP_DIR}
COPY setup/redis.conf /etc/supervisord.d/redis.conf

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=5s --retries=5 CMD curl --fail http://localhost:5000/api/3/action/status_show || exit 1

CMD ["/srv/app/start_ckan.sh"]
