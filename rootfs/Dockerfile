##################
### Build CKAN ###
##################
FROM ubuntu:18.04 as ckanbuild

# Set CKAN version to build
ENV GIT_URL=https://github.com/ckan/ckan.git
ENV GIT_BRANCH=ckan-2.8.2

# Set src dirs
ENV SRC_DIR=/srv/app/src
ENV PIP_SRC=${SRC_DIR}

WORKDIR ${SRC_DIR}

# Packages to build CKAN requirements and plugins
RUN apt-get update && apt-get install -y \
        git \
        curl \
        python \
        postgresql-server-dev-all \
        linux-headers-$(uname -r) \
        gcc \
        make \
        g++ \
        autoconf \
        automake \
        libtool \
        musl-dev \
        libpcre3 \
        libpcre3-dev \
        python-dev

# Create the src directory
RUN mkdir -p ${SRC_DIR}

# Install pip
RUN curl -o ${SRC_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python ${SRC_DIR}/get-pip.py

# Fetch and build CKAN and requirements
RUN pip install -e git+${GIT_URL}@${GIT_BRANCH}#egg=ckan
RUN rm -rf /srv/app/src/ckan/.git
RUN pip wheel --wheel-dir=/wheels -r ckan/requirements.txt
RUN pip wheel --wheel-dir=/wheels uwsgi gevent

############
### MAIN ###
############
FROM ubuntu:18.04

MAINTAINER Keitaro Inc <info@keitaro.com>

ENV APP_DIR=/srv/app
ENV SRC_DIR=/srv/app/src
ENV PIP_SRC=${SRC_DIR}
ENV CKAN_SITE_URL=http://localhost:5000
ENV CKAN__PLUGINS envvars image_view text_view recline_view datastore datapusher

WORKDIR ${APP_DIR}

# Install necessary packages to run CKAN
RUN apt-get update && apt-get install -y \
        git \
        gettext \
        curl \
        postgresql-client \
        python \
        libmagic-dev \
        libpcre3 \
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

# Additional install steps for build stages artifacts
RUN pip install --no-index --find-links=/srv/app/wheels uwsgi gevent

# Create a local user and group to run the app

RUN groupadd ckan
RUN useradd -d /srv/app -g ckan ckan 

# Install CKAN
RUN pip install -e /srv/app/src/ckan && \
    cd ${SRC_DIR}/ckan && \
    cp who.ini ${APP_DIR} && \
    pip install --no-index --find-links=/srv/app/wheels -r requirements.txt && \
    # Install CKAN envvars to support loading config from environment variables
    pip install -e git+https://github.com/okfn/ckanext-envvars.git@0.0.1#egg=ckanext-envvars && \
    # Create and update CKAN config
    paster --plugin=ckan make-config ckan ${APP_DIR}/production.ini && \
    paster --plugin=ckan config-tool ${APP_DIR}/production.ini "ckan.plugins = ${CKAN__PLUGINS}" && \
    # Change ownership to app user
    chown -R ckan:ckan /srv/app

# Remove wheels
RUN rm -rf /srv/app/wheels

# Create entrypoint directory for children image scripts
ONBUILD RUN mkdir docker-entrypoint.d

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=5s --retries=5 CMD curl --fail http://localhost:5000/api/3/action/status_show || exit 1

USER ckan

CMD ["/srv/app/start_ckan.sh"]
