# Build Oracle database image with read to use database instance for immediate start
# Based on image created with Dockerfile from https://github.com/oracle/docker-images/tree/master/OracleDatabase/SingleInstance/dockerfiles/12.2.0.1
# Peter Ramm, 09.01.2019

# Usage:
# increasing memory available for docker to 3GB via Docker > Preferences... > Advanced > Ram. It defaults to only 2 GB (on mac).
# Build image:                    > docker build --no-cache -t git.osp-dd.de:5005/pramm/panorama_gem_ci/database_prebuilt_panorama_test:11.2.0.4-ee -m 3g .
# Create container from image:    > docker run --name oracle_db_prebuilt_panorama_test_11.2.0.4-ee -p1521:1521 -d git.osp-dd.de:5005/pramm/panorama_gem_ci/database_prebuilt_panorama_test:11.2.0.4-ee

FROM git.osp-dd.de:5005/pramm/panorama_gem_ci/database_prebuilt:11.2.0.4-ee
MAINTAINER Peter Ramm <Peter.Ramm@ottogroup.com>

# Files are executed at instance startup
COPY    setup_db_in_build.sh create_awr_snapshots.sql create_panorama_test_user.sql modify_instance_settings.sql /home/oracle/

RUN     /bin/sh -c "/home/oracle/setup_db_in_build.sh"





