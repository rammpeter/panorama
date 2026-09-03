# syntax=docker/dockerfile:1.7
# Build application Panorama for Oracle
# Peter Ramm, 28.12.2016

# Usage:
# Build image:                    > docker build --build-arg JRUBY_VERSION=$JRUBY_VERSION -t rammpeter/panorama .
# Build with buildx:              > docker buildx build --progress=plain --build-arg JRUBY_VERSION=10.1.0.0 -t rammpeter/panorama --load .
# Create container from image:    > docker run --name panorama -p 8080:8080 -d rammpeter/panorama

# create container with tnsnames.ora from host and timezone set
# > docker run --name panorama -p 8080:8080 -v $TNS_ADMIN/tnsnames.ora:/etc/tnsnames.ora -e TNS_ADMIN=/etc -e TZ="Europe/Berlin" -d rammpeter/panorama:latest

# STAGE 2: App build
FROM docker.io/eclipse-temurin:25 AS build_stage

ENV BACKEND_SRC_PATH=.
ARG JRUBY_VERSION
ENV JRUBY_HOME=/opt/jruby-$JRUBY_VERSION
ENV PATH "$JRUBY_HOME/bin:$PATH"
ENV RAILS_ENV=production

WORKDIR /opt/panorama

COPY ${BACKEND_SRC_PATH} .

# Not nneded because done again st last stage
# RUN  microdnf update
# RUN  microdnf install wget tar gzip curl bash tzdata git make gcc

# libc6-dev provides the C headers (ctype.h etc.). gcc alone does not pull them in any more,
# without them "bundle install" fails while building the native extension of prism.
RUN apt-get update && apt-get install -y \
        wget ca-certificates tar gzip curl bash tzdata git make gcc libc6-dev nodejs && \
    rm -rf /var/lib/apt/lists/*
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

RUN  echo "gem: --no-rdoc --no-ri" > ~/.gemrc
RUN  gem install bundler
# terser is part of development/test group, but needed for assets:precompile
RUN  bundle config set deployment 'true'
RUN  bundle config install.args "--no-document"
RUN  rm -rf vendor/bundle # remove old vendor gems
# Ensure bundle install uses the correct JRE
RUN  bundle lock --add-platform universal-java-21 && bundle lock --add-platform universal-java-24

RUN  bundle config set --local without 'development test'
RUN  bundle install --jobs 4 --no-cache

RUN  bundle exec rake assets:precompile

RUN  rm -f vendor/cache/* && \
     rm -rf vendor/bundle/jruby/*/cache/*

RUN  rm -rf $HOME/.bundle/cache && \
     rm -f *.war                && \
     rm -f Panorama.log         && \
     rm -f Usage.log            && \
     rm -rf tmp/*               && \
     rm -rf log/*               && \
     rm -rf test/*

# log/ and tmp/ are excluded by .dockerignore, but Rails expects both directories to exist
# and does not create log/ itself when opening log/production.log
RUN  mkdir -p log tmp

### Shrink the two directories that are copied into the final image ###

# Only ojdbc11.jar is really loaded at runtime: the oracle_enhanced adapter requires it explicitly
# from ./lib (see jdbc_connection.rb, it looks for ojdbc11/8/7/6.jar only, not for ojdbc17.jar) and
# the JRuby classpath inside the container is just ".", so no other jar below lib/ is reachable.
# The wallet jars are kept because they are small and needed as soon as a wallet is used.
# The complete set remains in the repository for the Panorama.jar distribution, see config/jarble.rb
RUN  find lib -maxdepth 1 -name '*.jar' \
       ! -name 'ojdbc11.jar'   \
       ! -name 'oraclepki.jar' \
       ! -name 'osdt_cert.jar' \
       ! -name 'osdt_core.jar' \
       -delete

# maven-home is the complete Maven distribution that jar-dependencies pulls in to fetch jars
# at "bundle install" time. Nothing executes Maven at runtime, the gem itself stays intact.
RUN  rm -rf vendor/bundle/jruby/*/gems/ruby-maven-libs-*/maven-home

# prism ships the C extension sources and their build artifacts, which are useless on JRuby.
# prism is listed in excluded_gems.txt anyway, only its lib/ has to remain loadable.
RUN  rm -rf vendor/bundle/jruby/*/gems/prism-*/build \
            vendor/bundle/jruby/*/gems/prism-*/src   \
            vendor/bundle/jruby/*/gems/prism-*/ext   \
            vendor/bundle/jruby/*/gems/prism-*/rbi   \
            vendor/bundle/jruby/*/gems/prism-*/sig   \
            vendor/bundle/jruby/*/gems/prism-*/include

# share/ri is the RDoc documentation of the Ruby stdlib (~47 MB), rubygems-update is left over
# from "gem update --system" and lib/jni contains the native libs of 20+ foreign platforms.
RUN  rm -rf $JRUBY_HOME/share/ri \
            $JRUBY_HOME/samples  \
            $JRUBY_HOME/lib/ruby/gems/shared/cache/* \
            $JRUBY_HOME/lib/ruby/gems/shared/doc     \
            $JRUBY_HOME/lib/ruby/gems/shared/gems/rubygems-update-* \
            $JRUBY_HOME/lib/ruby/gems/shared/specifications/rubygems-update-*.gemspec && \
     find $JRUBY_HOME/lib/jni -mindepth 1 -maxdepth 1 -type d ! -name "$(uname -m)-Linux" -exec rm -rf {} +

# FROM scratch
FROM docker.io/eclipse-temurin:25-jre
LABEL org.opencontainers.image.authors="Peter Ramm <peter@ramm-oberhermsdorf.de>"

ARG JRUBY_VERSION
ENV JRUBY_HOME=/opt/jruby-$JRUBY_VERSION \
    WORKDIR=/opt/panorama
ENV PATH=$JRUBY_HOME/bin:$PATH

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl bash netbase && \
    rm -rf /var/lib/apt/lists/*


# RUN  microdnf update && microdnf clean all

WORKDIR $WORKDIR

COPY --from=build_stage $JRUBY_HOME $JRUBY_HOME
COPY --from=build_stage $WORKDIR    $WORKDIR

EXPOSE 8080/tcp

# use bracket syntax to ensure it runs with PID 1 and receives SIGTERM signal
CMD     ["/opt/panorama/run_Panorama_docker.sh"]

HEALTHCHECK --interval=5m --timeout=3s CMD curl localhost:8080 2>/dev/null | grep "Please choose saved connection " >/dev/null || exit 1
