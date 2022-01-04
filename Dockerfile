# Build application Panorama for Oracle
# Peter Ramm, 28.12.2016

# Usage:
# Build image:                    > docker build -t rammpeter/panorama .
# Create container from image:    > docker run --name panorama -p8080:8080 -d rammpeter/panorama

# create container with tnsnames.ora from host and timezone set
# > docker run --name panorama -p8080:8080 -v $TNS_ADMIN/tnsnames.ora:/etc/tnsnames.ora -e TNS_ADMIN=/etc -e TZ="Europe/Berlin" -d rammpeter/panorama:latest

FROM oraclelinux:8-slim as build_stage

ENV BACKEND_SRC_PATH=.
# Default for RAILS_MAX_THREADS to work for every CMD in docker container
ENV RAILS_MAX_THREADS=300
ENV JRUBY_VERSION=9.3.2.0
ENV PATH "$PATH:/opt/jruby-$JRUBY_VERSION/bin"

RUN  echo "### microdnf update" && \
     microdnf update && \
     echo "### add missing tools" && \
     microdnf install wget tar gzip curl bash tar wget procps findutils vim tzdata git && \
     echo "microdnf install procps vim util-linux podman jq bc" && \
     echo "### install java" && \
     wget https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.rpm && \
     rpm -Uvh jdk-17_linux-x64_bin.rpm && rm jdk-17_linux-x64_bin.rpm && \
     echo "### install jruby" && \
     cd /opt && wget https://repo1.maven.org/maven2/org/jruby/jruby-dist/$JRUBY_VERSION/jruby-dist-$JRUBY_VERSION-bin.tar.gz && \
     cd /opt && tar -xvf jruby-dist-$JRUBY_VERSION-bin.tar.gz && rm jruby-dist-$JRUBY_VERSION-bin.tar.gz && \
     ln -s /opt/jruby-$JRUBY_VERSION/bin/jruby /opt/jruby-$JRUBY_VERSION/bin/ruby && \
     ruby -v && \
     echo "### show  timezone" && \
     date && \
     echo '### due to error building digest-crc:6.0.3 sh: line 0: exec: jrake: not found' && \
     ln -s /opt/jruby-$JRUBY_VERSION/bin/rake /opt/jruby-$JRUBY_VERSION/bin/jrake && \
     echo "### update installed system gems" && \
     gem update --system --no-doc && \
     echo "### install bundler gems" && \
     gem install --no-document bundler && \
     echo "### set .gemrc" && \
     echo "gem: --no-rdoc --no-ri" > ~/.gemrc && \
     echo "### cleanup and list installed gems" && \
     gem cleanup && gem list


WORKDIR /opt/panorama

COPY ${BACKEND_SRC_PATH}/Gemfile* ./

RUN  bundle config set deployment 'true' && \
     bundle install --jobs 4

COPY ${BACKEND_SRC_PATH} .
RUN  bundle exec rake assets:precompile

RUN echo "### reduce storage / remove unnecessary packages" && \
    rm -f /usr/java/latest/lib/src.zip                      && \
    rm -f Panorama.war                                      && \
    rm -f Panorama.log                                      && \
    rm -f Usage.log                                         && \
    rm -rf tmp/cache/*                                      && \
    rm -rf log/*

FROM oraclelinux:8-slim as run_stage
MAINTAINER Peter Ramm <Peter@ramm-oberhermsdorf.de>

ENV JRUBY_VERSION   9.3.2.0
ENV PATH            "$PATH:/opt/jruby-$JRUBY_VERSION/bin"
ENV JAVA_HOME       /usr/java/latest

RUN   echo "### microdnf update" && \
      microdnf update && \
      echo "### Register java package" && \
      alternatives --install /usr/bin/java java /usr/java/latest/bin/java 1

WORKDIR /opt/panorama
COPY --from=build_stage /usr/java                   /usr/java
COPY --from=build_stage /opt/jruby-$JRUBY_VERSION   /opt/jruby-$JRUBY_VERSION
COPY --from=build_stage /opt/panorama               /opt/panorama

EXPOSE 8080/tcp

# use bracket syntax to ensure it runs with PID 1 and receives SIGTERM signal
CMD     ["/opt/panorama/run_Panorama_docker.sh"]

HEALTHCHECK --interval=5m --timeout=3s CMD curl localhost:8080 2>/dev/null | grep "Please choose saved connection " >/dev/null || exit 1