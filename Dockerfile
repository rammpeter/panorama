# Build application Panorama for Oracle
# Peter Ramm, 28.12.2016

# Usage:
# Build image:                    > docker build -t rammpeter/panorama .
# Create container from image:    > docker run --name panorama -p8080:8080 -d rammpeter/panorama

# create container with tnsnames.ora from host and timezone set
# > docker run --name panorama -p8080:8080 -v $TNS_ADMIN/tnsnames.ora:/etc/tnsnames.ora -e TNS_ADMIN=/etc -e TZ="Europe/Berlin" -d rammpeter/panorama:latest

FROM	openjdk:13
MAINTAINER Peter Ramm <Peter@ramm-oberhermsdorf.de>

RUN     useradd panorama                 &&\
        mkdir /opt/panorama              &&\
        chown panorama /opt/panorama     &&\
        mkdir /var/opt/panorama          &&\
        chown panorama /var/opt/panorama

USER    panorama
WORKDIR	/opt/panorama

COPY	Panorama.war run_Panorama_docker.sh /opt/panorama/

#RUN     echo "Europe/Berlin" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata
EXPOSE	8080
CMD	/opt/panorama/run_Panorama_docker.sh

#HEALTHCHECK --interval=5m --timeout=3s CMD wget localhost:8080/Panorama -O - 2>/dev/null | grep "Please choose saved connection " >/dev/null || exit 1
HEALTHCHECK --interval=5m --timeout=3s CMD curl localhost:8080/Panorama/ 2>/dev/null | grep "Please choose saved connection " >/dev/null || exit 1

