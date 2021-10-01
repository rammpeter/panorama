# Build application Panorama for Oracle
# Peter Ramm, 28.12.2016

# Usage:
# Build image:                    > docker build -t rammpeter/panorama .
# Create container from image:    > docker run --name panorama -p8080:8080 -d rammpeter/panorama

# create container with tnsnames.ora from host and timezone set
# > docker run --name panorama -p8080:8080 -v $TNS_ADMIN/tnsnames.ora:/etc/tnsnames.ora -e TNS_ADMIN=/etc -e TZ="Europe/Berlin" -d rammpeter/panorama:latest

#FROM	openjdk:16
FROM   openjdk:17-jdk-alpine
MAINTAINER Peter Ramm <Peter@ramm-oberhermsdorf.de>

# There is no yum in openjdk images starting with openjdk:14, microdnf update instead
RUN     apk update && apk upgrade && apk add bash && \
        mkdir /opt/panorama         && \
        mkdir /var/opt/panorama

# USER    panorama          # No useradd or yum command supported in openjdk images yet
WORKDIR	/opt/panorama

COPY	Panorama.war run_Panorama_docker.sh /opt/panorama/

#RUN     echo "Europe/Berlin" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata
EXPOSE	8080
CMD	/opt/panorama/run_Panorama_docker.sh

#HEALTHCHECK --interval=5m --timeout=3s CMD wget localhost:8080/Panorama -O - 2>/dev/null | grep "Please choose saved connection " >/dev/null || exit 1
HEALTHCHECK --interval=5m --timeout=3s CMD curl localhost:8080/Panorama/ 2>/dev/null | grep "Please choose saved connection " >/dev/null || exit 1

