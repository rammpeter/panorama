# Build Oracle database image
# Peter Ramm, 16.04.2019

# Parameter : Database version, e.g. 12.1.0.2-ee, 18.3.0.0-se

# Use this script instead of building directly with dockerfiles
if [ $# -ne 2 ]
then
  echo "Parameter base-image and target-image expected"
  exit 1
fi

export BASE_IMAGE=$1
export TARGET_IMAGE=$2

# Service-Name in lsnrctl
export CDB_SERVICE=ORCLCDB
export PDB_SERVICE=orclpdb1

if [[ $BASE_IMAGE =~ "xe" ]]; then
  export CDB_SERVICE=XE
  export PDB_SERVICE=xepdb1
fi

# Ensure that image is loaded before docker inspect
# Supressed to ensure using local image instead of possibly older image in registry
# docker pull $BASE_IMAGE

# get environment from base image and replace in Dockerfile
docker inspect ${BASE_IMAGE} | jq ".[0].Config.Env" |
  sed 's/"//g; s/,//; s/^/ENV /; s/\//\\\//g'  |
  grep -v "\[" | grep -v "\]" |
  awk '{printf "%s\\n", $0}' > base.env

sed "s/BASE_ENV/$(cat base.env)/" Dockerfile > Dockerfile.modified

echo "Building Oracle database for $TARGET_IMAGE"
# add --squash if it is not experimental no more
# Disable DOCKER_BUILDKIT as workaround for "/sys/fs/cgroup/memory.max no such file or directory" see: https://github.com/oracle/docker-images/issues/2334
DOCKER_BUILDKIT=0 docker build --no-cache \
--build-arg BASE_IMAGE=$BASE_IMAGE \
--build-arg CDB_SERVICE=$CDB_SERVICE \
--build-arg PDB_SERVICE=$PDB_SERVICE \
-f Dockerfile.modified \
-t $TARGET_IMAGE -m 3g .

