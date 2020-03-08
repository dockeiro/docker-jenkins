FROM openjdk:8-jdk-alpine

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="gustavo8000br version:- ${VERSION} Build-date:- ${BUILD_DATE}"

RUN apk add --no-cache git openssh-client curl unzip bash ttf-dejavu coreutils tini

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home

ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN mkdir -p $JENKINS_HOME \
    && chown ${uid}:${gid} $JENKINS_HOME \
    && addgroup -g ${gid} ${group} \
    && adduser -h "$JENKINS_HOME" -u ${uid} -G ${group} -s /bin/bash -D ${user}

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# `/usr/share/jenkins/ref/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
RUN if [ -z ${JENKINS_VERSION+x} ]; then \
	JENKINS_VERSION=$(curl -s http://mirrors.jenkins.io/war-stable/ \
  | grep DIR | tail -n2 | head -n1 | sed 's/^.*href="//; s/\/".*//'); \
  fi

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA_URL=http://mirrors.jenkins-ci.org/war-stable/${JENKINS_VERSION}/jenkins.war.sha256

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=http://mirrors.jenkins-ci.org/war-stable/${JENKINS_VERSION}/jenkins.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN echo "**** install jenkins ****" \
  && cd /usr/share/jenkins \
  && curl -fSL ${JENKINS_URL} -o jenkins.war \
  && curl -fSL ${JENKINS_SHA_URL} -o jenkins.war.sha256 && sha256sum -c jenkins.war.sha256 \
  && rm jenkins.war.sha256 \
  && cd /

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${user}

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY tini-shim.sh /bin/tini
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
