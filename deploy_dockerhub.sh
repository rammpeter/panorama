# Deploy Panorama to Dockerhub.com and Dockerhub.osp-dd.de
# Peter Ramm, 29.01.2017

# docker login must be succesfully succeded
echo "Deploy Panorama.war as Docker image to dockerhub.com"

# Ensure using latest version
docker pull anapsix/alpine-java:8_server-jre_unlimited

VERSION_FILE="`bundle show panorama_gem --paths`/lib/panorama_gem/version.rb"
echo VERSION_FILE=$VERSION_FILE
PANORAMA_VERSION=`cat $VERSION_FILE | grep "VERSION =" | cut -d " " -f5 | sed "s/'//g"`
echo PANORAMA_VERSION=$PANORAMA_VERSION

docker build -t rammpeter/panorama .

# Aktualisierung Dockerhub.com
docker tag rammpeter/panorama:latest rammpeter/panorama:$PANORAMA_VERSION

docker push rammpeter/panorama:latest
docker push rammpeter/panorama:$PANORAMA_VERSION

# Aktualisierung Dockerhub.osp-dd.de
docker tag rammpeter/panorama:latest dockerhub.osp-dd.de/pramm/panorama:latest
docker tag rammpeter/panorama:latest dockerhub.osp-dd.de/pramm/panorama:$PANORAMA_VERSION

docker push dockerhub.osp-dd.de/pramm/panorama:latest
docker push dockerhub.osp-dd.de/pramm/panorama:$PANORAMA_VERSION



