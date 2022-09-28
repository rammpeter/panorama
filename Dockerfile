# Build application Panorama for Oracle
# Peter Ramm, 28.12.2016

# Usage:
# Build image:                    > docker build -t rammpeter/panorama .
# Create container from image:    > docker run --name panorama -p8080:8080 -d rammpeter/panorama

# create container with tnsnames.ora from host and timezone set
# > docker run --name panorama -p8080:8080 -v $TNS_ADMIN/tnsnames.ora:/etc/tnsnames.ora -e TNS_ADMIN=/etc -e TZ="Europe/Berlin" -d rammpeter/panorama:latest

# STAGE 1: JRE build
FROM openjdk:19 as openjdk

# Build small JRE image
RUN $JAVA_HOME/bin/jlink \
         --verbose \
         --add-modules ALL-MODULE-PATH \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /customjre

# STAGE 2: App build
FROM oraclelinux:8-slim as build_stage

ENV BACKEND_SRC_PATH=.
ARG JRUBY_VERSION
ENV JAVA_HOME=/opt/jre
ENV PATH "${JAVA_HOME}/bin:/opt/jruby-$JRUBY_VERSION/bin:$PATH"

WORKDIR /opt/panorama

COPY --from=openjdk /customjre $JAVA_HOME
COPY ${BACKEND_SRC_PATH} .

RUN  echo "### microdnf update" && \
     microdnf update && \
     echo "### add missing tools" && \
     microdnf install wget tar gzip curl bash tar wget procps findutils vim tzdata git && \
     echo "### install jruby" && \
     (cd /opt && wget https://repo1.maven.org/maven2/org/jruby/jruby-dist/$JRUBY_VERSION/jruby-dist-$JRUBY_VERSION-bin.tar.gz) && \
     (cd /opt && tar -xvf jruby-dist-$JRUBY_VERSION-bin.tar.gz && rm jruby-dist-$JRUBY_VERSION-bin.tar.gz) && \
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
     echo "### bundle config set deployment 'true'" && \
     bundle config set deployment 'true' && \
     echo "### remove old vendor gems" && \
     rm -rf vendor/bundle && \
     echo "### bundle install" && \
     bundle install --jobs 4 && \
     echo "### bundle exec rake assets:precompile" && \
     bundle exec rake assets:precompile && \
     echo "### reduce storage / remove unnecessary packages" && \
     gem cleanup && gem list && \
     microdnf clean all && \
     rm -rf $HOME/.bundle/cache && \
     rm -f *.war                                      && \
     rm -f Panorama.log                                      && \
     rm -f Usage.log                                         && \
     rm -rf tmp/cache/*                                      && \
     rm -rf log/*

FROM scratch
MAINTAINER Peter Ramm <Peter@ramm-oberhermsdorf.de>

ARG JRUBY_VERSION
ENV JAVA_HOME=/opt/jre
ENV PATH "${JAVA_HOME}/bin:/opt/jruby-$JRUBY_VERSION/bin:$PATH"

WORKDIR /opt/panorama

COPY --from=build_stage / /

EXPOSE 8080/tcp

# use bracket syntax to ensure it runs with PID 1 and receives SIGTERM signal
CMD     ["/opt/panorama/run_Panorama_docker.sh"]

HEALTHCHECK --interval=5m --timeout=3s CMD curl localhost:8080 2>/dev/null | grep "Please choose saved connection " >/dev/null || exit 1
