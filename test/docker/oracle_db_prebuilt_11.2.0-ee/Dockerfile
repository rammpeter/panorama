# Build Oracle database image with read to use database instance for immediate start
# Based on image created with Dockerfile from Andreas Gungl http://gitlab.osp-dd.de/main/oracle11g
# Peter Ramm, 10.01.2019

# Usage:
# increasing memory available for docker to 3GB via Docker > Preferences... > Advanced > Ram. It defaults to only 2 GB (on mac).
# Build image:                    > docker build --no-cache -t git.osp-dd.de:5005/pramm/panorama_gem_ci/database_prebuilt:11.2.0.4-ee -m 3g .
# Create container from image:    > docker run --name oracle_db_prebuilt_11.2.0.4-ee -p1521:1521 -d git.osp-dd.de:5005/pramm/panorama_gem_ci/database_prebuilt:11.2.0.4-ee

FROM git.osp-dd.de:5005/pramm/panorama_gem_ci/database:11.2.0.4-ee
MAINTAINER Peter Ramm <Peter.Ramm@ottogroup.com>

COPY    install_db_in_build.sh run_db_in_container.sh check_DBStatus.sh /home/oracle/

# Create database instance
RUN     /bin/sh -c "/home/oracle/install_db_in_build.sh"

EXPOSE  1521 5500
CMD     /bin/sh -c "/home/oracle/run_db_in_container.sh"

HEALTHCHECK --interval=1m --start-period=30s CMD "/home/oracle/check_DBStatus.sh" >/dev/null || exit 1


