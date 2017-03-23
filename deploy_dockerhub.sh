# Deploy Panorama to Dockerhub
# Peter Ramm, 29.01.2017

echo "Deploy Panorama.war as Docker image to dockerhub.com"
VERSION_FILE="`bundle show panorama_gem --paths`/lib/panorama_gem/version.rb"
echo VERSION_FILE=$VERSION_FILE
PANORAMA_VERSION=`cat $VERSION_FILE | grep "VERSION =" | cut -d " " -f5 | sed "s/'//g"`
echo PANORAMA_VERSION=$PANORAMA_VERSION

docker build -t rammpeter/panorama .

docker tag rammpeter/panorama:latest rammpeter/panorama:$PANORAMA_VERSION

docker push rammpeter/panorama:latest
docker push rammpeter/panorama:$PANORAMA_VERSION

