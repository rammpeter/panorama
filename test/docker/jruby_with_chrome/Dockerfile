# Build Debian image with jruby and chromium
# Peter Ramm, 03.12.2018

# Usage:
# increasing memory available for docker to 3GB via Docker > Preferences... > Advanced > Ram. It defaults to only 2 GB (on mac).
# Build image:
# > docker pull oraclelinux:8-slim
# > docker build --no-cache -t rammpeter/jruby_with_chrome:9.4.0.0 .


FROM oraclelinux:8-slim

MAINTAINER Peter.Ramm@ottogroup.com
ARG JRUBY_VERSION=9.4.0.0
ENV JRUBY_VERSION=$JRUBY_VERSION
ENV PATH "$PATH:/opt/jruby-$JRUBY_VERSION/bin"

# Allow chromedriver to use this port at all interfaces
EXPOSE  9515


# RUN-Steps:
# - update system
# - install tools
# - install podman
RUN  microdnf update && \
     microdnf install procps wget tar gzip vim git make findutils util-linux podman jq bc dnf && \
     wget https://download.oracle.com/java/19/latest/jdk-19_linux-x64_bin.rpm && \
     rpm -Uvh jdk-19_linux-x64_bin.rpm && rm jdk-19_linux-x64_bin.rpm && \
     dnf install -y @nodejs && \
     cd /opt && wget https://repo1.maven.org/maven2/org/jruby/jruby-dist/$JRUBY_VERSION/jruby-dist-$JRUBY_VERSION-bin.tar.gz && \
     cd /opt && tar -xvf jruby-dist-$JRUBY_VERSION-bin.tar.gz && rm jruby-dist-$JRUBY_VERSION-bin.tar.gz && \
     ln -s /opt/jruby-$JRUBY_VERSION/bin/jruby /opt/jruby-$JRUBY_VERSION/bin/ruby && \
     ruby -v && \
     npm install playwright && \
     wget "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm" && \
     microdnf install liberation-fonts libXScrnSaver.x86_64 libappindicator-gtk3.x86_64 vulkan libgbm xdg-utils alsa-lib nspr nss && \
     rpm -i google-chrome-stable_current_x86_64.rpm && \
     rm google-chrome-stable_current_x86_64.rpm && \
     echo 'Europe/Berlin' > /etc/timezone && rm -f /etc/localtime && ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime && \
     date && \
     gem install --no-doc bundler && \
     echo "gem: --no-rdoc --no-ri" > ~/.gemrc






