# Deploy Panorama to Dockerhub.com and Dockerhub.osp-dd.de
# Peter Ramm, 29.01.2017

VERSION_FILE="config/application.rb"
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
if [ $? -ne 0 ]; then
  echo "########## error while docker push :latest ##########"
  exit 1
fi
docker push rammpeter/panorama:$PANORAMA_VERSION
if [ $? -ne 0 ]; then
  echo "########## error while docker push :$PANORAMA_VERSION ##########"
  exit 1
fi




