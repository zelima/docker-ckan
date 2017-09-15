##################
### Build CKAN ###
##################
FROM keitaro/ckanbuildenv:0.2 as ckanbuild

# Set CKAN version to build
ENV GIT_URL=https://github.com/ckan/ckan.git
ENV GIT_BRANCH=ckan-2.6.3

WORKDIR ${SRC_DIR}
RUN pip install -e git+${GIT_URL}@${GIT_BRANCH}#egg=ckan
RUN rm -rf /srv/app/src/ckan/.git
RUN pip wheel --wheel-dir=/wheels -r ckan/requirements.txt

#####################
### Build libgeos ###
#####################
FROM keitaro/ckanbuildenv:0.2 as geosbuild

# Set geos verson to build
ENV GEOS_VERSION=3.6.1

WORKDIR ${SRC_DIR}/geos
RUN git clone -b ${GEOS_VERSION} --depth=1 --single-branch https://git.osgeo.org/gogs/geos/geos.git ${SRC_DIR}/geos
RUN ./autogen.sh
RUN ./configure --prefix /usr/local
RUN make -j2
RUN make install-strip

###################
### Build uwsgi ###
###################
FROM keitaro/ckanbuildenv:0.2 as uwsgibuild
RUN pip wheel --wheel-dir=/wheels uwsgi gevent

############
### MAIN ###
############
FROM keitaro/base:0.3

MAINTAINER Keitaro Inc <info@keitaro.com>

ENV APP_DIR=/srv/app
ENV SRC_DIR=/srv/app/src
ENV PIP_SRC=${SRC_DIR}
ENV CKAN_SITE_URL=http://localhost:5000
ENV CKAN__PLUGINS image_view text_view recline_view datastore datapusher envvars

WORKDIR ${APP_DIR}

# Install necessary packages to run CKAN
RUN apk add --no-cache git \
        gettext \
        postgresql-client \
        python \
        apache2-utils \
        varnish && \
    # Create SRC_DIR
    mkdir -p ${SRC_DIR}

# Install pip
RUN curl -o ${SRC_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python ${SRC_DIR}/get-pip.py

# Get artifacts from build stages
COPY --from=geosbuild /usr/local /usr/local
COPY --from=uwsgibuild /wheels /srv/app/wheels
COPY --from=ckanbuild /wheels /srv/app/wheels
COPY --from=ckanbuild /srv/app/src/ckan /srv/app/src/ckan

# Additional install steps for build stages artifacts
RUN pip install --no-index --find-links=/srv/app/wheels uwsgi gevent

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
    # Create and update CKAN config
    paster --plugin=ckan make-config ckan ${APP_DIR}/production.ini && \
    paster --plugin=ckan config-tool ${APP_DIR}/production.ini "ckan.plugins = ${CKAN__PLUGINS}" && \
    # Change ownership to app user
    chown -R ckan:ckan /srv/app && \
    # Remove wheels
    rm -rf /srv/app/wheels

COPY setup/app ${APP_DIR}
COPY setup/varnish/default.vcl /etc/varnish/default.vcl

RUN chown -R ckan:ckan /etc/varnish /var/lib/varnish

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=5s --retries=5 CMD curl --fail http://localhost:5000/api/3/action/status_show || exit 1

USER ckan

CMD ["/srv/app/start_ckan.sh"]
