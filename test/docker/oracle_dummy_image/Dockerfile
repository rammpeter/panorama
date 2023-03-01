# Build Oracle database image with no function
# Used as service for autonomous DB
# Peter Ramm, 2022-05-04

# Usage:
# Build image:                    > docker build -t harbor.osp-dd.de/panorama/oracle/database_prebuilt_panorama_test:autonomous .

FROM alpine
MAINTAINER Peter Ramm <Peter.Ramm@ottogroup.com>
EXPOSE  1521
WORKDIR /app
COPY run.sh .
CMD /app/run.sh
HEALTHCHECK CMD exit 0



