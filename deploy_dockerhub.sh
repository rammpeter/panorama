# Deploy Panorama to Dockerhub.com and Dockerhub.osp-dd.de
# Peter Ramm, 29.01.2017

VERSION_FILE="`bundle info panorama_gem --path`/lib/panorama_gem/version.rb"
echo VERSION_FILE=$VERSION_FILE
PANORAMA_VERSION=`cat $VERSION_FILE | grep "VERSION =" | cut -d " " -f5 | sed "s/'//g"`
echo PANORAMA_VERSION=$PANORAMA_VERSION

./create_docker_image.sh 
if [ $? -ne 0 ]
then
  echo "Error during create_docker_image.sh, exit"
  exit 1
fi

# docker login must be succesfully succeded
echo "Deploy Panorama.war as Docker image to dockerhub.com"

# Aktualisierung Dockerhub.com
docker tag rammpeter/panorama:latest rammpeter/panorama:$PANORAMA_VERSION

# $DH_TOKEN ist set in local workstation environment
docker login -u rammpeter -p $DH_TOKEN

# Check active login at dockerhub
grep "https://index.docker.io/v1/" ~/.docker/config.json >/dev/null
if [ $? -ne 0 ]; then
  echo "########## You are not logged in to dockerhub! Please login before ##########"
  exit 1
fi

docker push rammpeter/panorama:latest
docker push rammpeter/panorama:$PANORAMA_VERSION

# Aktualisierung Dockerhub.osp-dd.de
docker tag rammpeter/panorama:latest dockerhub.osp-dd.de/pramm/panorama:latest
docker tag rammpeter/panorama:latest dockerhub.osp-dd.de/pramm/panorama:$PANORAMA_VERSION

docker push dockerhub.osp-dd.de/pramm/panorama:latest
docker push dockerhub.osp-dd.de/pramm/panorama:$PANORAMA_VERSION



