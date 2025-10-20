# Build application Panorama for Oracle
# Peter Ramm, 28.12.2016

# Usage:
# Build image:                    > docker build -t rammpeter/panorama .
# Create container from image:    > docker run --name panorama -p 8080:8080 -d rammpeter/panorama

# create container with tnsnames.ora from host and timezone set
# > docker run --name panorama -p 8080:8080 -v $TNS_ADMIN/tnsnames.ora:/etc/tnsnames.ora -e TNS_ADMIN=/etc -e TZ="Europe/Berlin" -d rammpeter/panorama:latest

# STAGE 1: JRE build
FROM docker.io/eclipse-temurin:21 as openjdk
#FROM openjdk:19 as openjdk

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
FROM docker.io/oraclelinux:8-slim as build_stage

ENV BACKEND_SRC_PATH=.
ARG JRUBY_VERSION
ENV JAVA_HOME=/opt/jre
ENV JRUBY_HOME=/opt/jruby-$JRUBY_VERSION
ENV PATH "${JAVA_HOME}/bin:$JRUBY_HOME/bin:$PATH"
ENV RAILS_ENV=production

WORKDIR /opt/panorama

COPY --from=openjdk /customjre $JAVA_HOME
COPY ${BACKEND_SRC_PATH} .

# Not nneded because done again st last stage
# RUN  microdnf update
RUN  microdnf install wget tar gzip curl bash tzdata git
# RUN  microdnf install wget tar gzip curl bash tzdata make clang git
RUN  echo "### install jruby" && \
     (cd /opt && wget https://repo1.maven.org/maven2/org/jruby/jruby-dist/$JRUBY_VERSION/jruby-dist-$JRUBY_VERSION-bin.tar.gz) && \
     (cd /opt && tar -xvf jruby-dist-$JRUBY_VERSION-bin.tar.gz && rm jruby-dist-$JRUBY_VERSION-bin.tar.gz) && \
     ruby -v
RUN  date # show  timezone
RUN  echo '### due to error building digest-crc:6.0.3 sh: line 0: exec: jrake: not found' && \
     ln -s /opt/jruby-$JRUBY_VERSION/bin/rake /opt/jruby-$JRUBY_VERSION/bin/jrake

RUN  echo "### update installed system gems" && \
     gem update --system --no-doc

RUN  gem install --no-document bundler
RUN  echo "gem: --no-rdoc --no-ri" > ~/.gemrc
RUN  bundle config set deployment 'true'
RUN  bundle config set --local without 'development test'
RUN  bundle config install.args "--no-document"
RUN  rm -rf vendor/bundle # remove old vendor gems
# Ensure bundle install uses the correct JRE
RUN  bundle lock --add-platform universal-java-21 && bundle lock --add-platform universal-java-24
RUN  bundle install --jobs 4 --no-cache
RUN  bundle exec rake assets:precompile
# RUN  echo "### reduce storage / remove unnecessary packages" && gem cleanup && gem list && \
#RUN  microdnf remove libmetalink expat wget tar gzip make gcc binutils glibc-devel libxcrypt-devel glibc-headers kernel-headers \
#     libgomp pkgconf-pkg-config pkgconf libpkgconf pkgconf-m4 isl cpp libmpc

RUN  rm -f vendor/cache/* && \
     rm -rf vendor/bundle/jruby/*/cache/*

RUN  microdnf clean all
RUN  rm -rf $HOME/.bundle/cache && \
     rm -f *.war                && \
     rm -f Panorama.log         && \
     rm -f Usage.log            && \
     rm -rf tmp/*               && \
     rm -rf log/*               && \
     rm -rf test/*

# FROM scratch
FROM docker.io/oraclelinux:8-slim
MAINTAINER Peter Ramm <Peter@ramm-oberhermsdorf.de>

ARG JRUBY_VERSION
ENV JAVA_HOME=/opt/jre \
    JRUBY_HOME=/opt/jruby-$JRUBY_VERSION \
    WORKDIR=/opt/panorama
ENV PATH $JAVA_HOME/bin:$JRUBY_HOME/bin:$PATH

RUN  microdnf update && microdnf clean all

WORKDIR $WORKDIR

COPY --from=build_stage $JAVA_HOME  $JAVA_HOME
COPY --from=build_stage $JRUBY_HOME $JRUBY_HOME
COPY --from=build_stage $WORKDIR    $WORKDIR

# COPY --from=build_stage / /

EXPOSE 8080/tcp

# use bracket syntax to ensure it runs with PID 1 and receives SIGTERM signal
CMD     ["/opt/panorama/run_Panorama_docker.sh"]

HEALTHCHECK --interval=5m --timeout=3s CMD curl localhost:8080 2>/dev/null | grep "Please choose saved connection " >/dev/null || exit 1
