# Build application Panorama for Oracle
# Peter Ramm, 28.12.2016

# Usage:
# Build image:                    > docker build -t rammpeter/panorama .
# Create container from image:    > docker run --name panorama -p8080:8080 -d rammpeter/panorama

# create container with tnsnames.ora from host and timezone set
# > docker run --name panorama -p8080:8080 -v $TNS_ADMIN/tnsnames.ora:/etc/tnsnames.ora -e TNS_ADMIN=/etc -e TZ="Europe/Berlin" -d rammpeter/panorama:latest

#FROM	java:8-jre
FROM	anapsix/alpine-java:8_server-jre_unlimited
MAINTAINER Peter@ramm-oberhermsdorf.de

WORKDIR	/opt/panorama
COPY	Panorama.war run_Panorama_docker.sh /opt/panorama/
#RUN     echo "Europe/Berlin" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata
EXPOSE	8080
CMD	/opt/panorama/run_Panorama_docker.sh

