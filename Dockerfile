# Build application Panorama for Oracle
# Peter Ramm, 28.12.2016

# Usage:
# Build image:                    > docker build -t panorama-2.4.72 .
# Create container from image:    > docker run --name panorama -p8080:8080 -d panorama-2.4.72 

FROM	java:8-jre
MAINTAINER Peter@ramm-oberhermsdorf.de

WORKDIR	/opt/panorama
COPY	Panorama.war run_Panorama_docker.sh /opt/panorama/
#RUN     echo "Europe/Berlin" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata
EXPOSE	8080
CMD	/opt/panorama/run_Panorama_docker.sh

