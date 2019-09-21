# Deploy Panorama to Dockerhub.com and Dockerhub.osp-dd.de
# Peter Ramm, 21.09.2019

# Ensure using latest version
#docker pull anapsix/alpine-java:8_server-jre_unlimited
docker pull openjdk:13

VERSION_FILE="`bundle show panorama_gem --paths`/lib/panorama_gem/version.rb"
echo VERSION_FILE=$VERSION_FILE
PANORAMA_VERSION=`cat $VERSION_FILE | grep "VERSION =" | cut -d " " -f5 | sed "s/'//g"`
echo PANORAMA_VERSION=$PANORAMA_VERSION

docker build -t rammpeter/panorama .
RC=$?
if [ $RC -ne 0 ]
then
  echo "Error $RC during docker build, exit"
  exit $RC
fi
docker tag rammpeter/panorama:latest rammpeter/panorama:$PANORAMA_VERSION




