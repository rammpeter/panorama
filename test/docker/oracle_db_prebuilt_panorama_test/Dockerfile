# Build Oracle database image with ready to use database instance for immediate start
# Peter Ramm, 09.01.2019

# Usage:
# increasing memory available for docker to 3GB via Docker > Preferences... > Advanced > Ram. It defaults to only 2 GB (on mac).
# use ./build_panorama_db_image.sh to start build

# Default if no argument is given from docker build
ARG BASE_IMAGE=registry:0.0.0.0-ee

FROM ${BASE_IMAGE} as base
MAINTAINER Peter Ramm <Peter.Ramm@ottogroup.com>

COPY    setup_db_in_build.sh create_panorama_test_user.sql analyze_sys_schemas.sql modify_instance_settings.sql $ORACLE_BASE/

# Files are executed at instance startup
COPY    create_awr_snapshots.sql $ORACLE_BASE/scripts/startup/

RUN     /bin/sh -c "$ORACLE_BASE/setup_db_in_build.sh"

USER    root
RUN     rm -rf /var/log/*

# Update OS to current patch state
RUN     yum -y update && yum clean all

FROM scratch

ARG CDB_SERVICE=ORCLCDB
ARG PDB_SERVICE=orclpdb1
ENV CDB_SERVICE ${CDB_SERVICE}
ENV PDB_SERVICE ${PDB_SERVICE}

BASE_ENV

COPY --from=base / /

USER    oracle

WORKDIR /home/oracle

EXPOSE  1521 5500
# use bracket syntax to ensure that run_db_in_container.sh runs with PID 1 and receives SIGTERM signal
CMD ["/bin/sh", "-c", "$ORACLE_BASE/run_db_in_container.sh"]

# Ensure that both services are active in listener and original health check is successful
HEALTHCHECK --interval=30s --start-period=10s --retries=5 \
    CMD lsnrctl status | grep "Service \"${CDB_SERVICE}\" has" && lsnrctl status | grep "Service \"${PDB_SERVICE}\" has" && $ORACLE_BASE/$CHECK_DB_FILE




